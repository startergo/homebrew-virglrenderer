# Upstream handoff

The [standalone patch](0001-vrend-select-dual-source-output-layout.patch) applies to clean upstream commit `cf6c62da2a1384b194f463e6221371962fe99575`. It is provided for submission by a contributor with freedesktop GitLab access; no upstream merge request has been opened for this patch. This file and patch are handoff artifacts, not additional patches applied by the Homebrew formula.

When a GLES fragment shader declares both primary and secondary color outputs with `FS_COLOR0_WRITES_ALL_CBUFS`, the broadcast output layout assigns the secondary output a separate render-target location. This conflicts with dual-source blending, which needs the secondary output at location zero, index one.

Select a shader variant from the active blend state and suppress broadcast declarations only for enabled GLES dual-source blending. Mark shaders dirty when the blend object is unbound so the output layout is reconsidered.

This is an alternative to [upstream !1668](https://gitlab.freedesktop.org/virgl/virglrenderer/-/merge_requests/1668). That proposal identifies the same output-layout problem and notes the ordinary-blending limitation. Keeping the decision in the shader key preserves broadcasting when the same shader is used without dual-source blending. The ordinary-broadcast regression passes on unmodified upstream and this patch, and fails with !1668 applied to the same upstream base.

Adds native Meson/Check coverage: four shader-translation cases (dual source, ordinary blending with the same shader, depth output, and MRT) and two blend-state cases (variant selection and null-object invalidation). No macOS packaging changes are included.

Validation against upstream `cf6c62da2a1384b194f463e6221371962fe99575`, using a disposable Ubuntu 24.04 arm64 container and Mesa software rendering:

| Suite | Unmodified upstream | Patched |
| --- | --- | --- |
| Desktop GL | 8/8 executables pass | 10/10 executables pass |
| GLES | 6/8 executables pass | 8/10 executables pass |

All six new Check cases pass in both modes. Both GLES runs have the same existing failures: two transfer assertions and unsupported query buffers. The baseline regression comparison uses a test-only shim for the absent shader-key member; it does not modify baseline production code and is not included in this patch.

Separately, the equivalent fix was exercised in a macOS ANGLE-backed QEMU guest against older packaged virglrenderer sources: Alacritty's dual-source text rendered correctly, including resize and reopen checks. Those runtime checks are supporting evidence, not a claim that this upstream revision was packaged or tested on macOS.
