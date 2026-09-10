#!/usr/bin/env python3
"""Compile regression tests against an existing Meson build, then run them."""
import argparse
import json
from pathlib import Path
import shlex
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("build", type=Path, help="existing virglrenderer Meson build")
parser.add_argument("output", type=Path, help="separate directory for test executables")
parser.add_argument("link_args", nargs=argparse.REMAINDER, help="extra dependency linker arguments after --")
args = parser.parse_args()
build = args.build.resolve()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
commands = json.loads((build / "compile_commands.json").read_text())
tests = Path(__file__).resolve().parent
link_args = args.link_args
if link_args[:1] == ["--"]:
    link_args = link_args[1:]


def compile_test(name, implementation):
    entry = next(item for item in commands if item["file"].endswith("/" + implementation))
    command = entry.get("arguments") or shlex.split(entry["command"])
    directory = Path(entry["directory"])
    source_file = (directory / entry["file"]).resolve()
    source = source_file.parents[1]
    flags = []
    index = 1
    while index < len(command):
        flag = command[index]
        if flag in ("-o", "-MF", "-MQ", "-MT"):
            index += 2
            continue
        if flag in ("-c", "-MD", "-MMD") or flag.endswith("/" + implementation):
            index += 1
            continue
        flags.append(flag)
        index += 1
    header = source / "vrend" / "vrend_shader.h"
    if "uint32_t dual_src_blend : 1" in header.read_text():
        flags.append("-DVIRGL_HAS_DUAL_SOURCE_KEY")
    flags += ["-I" + str(source), "-I" + str(source / "vrend")]
    archives = [build / "src/libvirgl.a", build / "src/gallium/libgallium.a", build / "src/mesa/libmesa.a"]
    binary = output / name
    subprocess.run([command[0], *flags, str(tests / (name + ".c")),
                    *map(str, archives), *link_args, "-o", str(binary)],
                   cwd=directory, check=True)
    return subprocess.run([str(binary)], cwd=output).returncode


failures = 0
for name, implementation in (("test-dual-source-shader", "vrend_shader.c"),
                             ("test-null-blend", "vrend_renderer.c")):
    failures += compile_test(name, implementation) != 0
sys.exit(bool(failures))
