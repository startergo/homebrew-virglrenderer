# Driver regression tests

The formula runs these tests after compiling virglrenderer and before installing it.
They use the build's compiler flags and static libraries; no display, virtual machine,
or `check` package is needed.

- `test-dual-source-shader.c` translates real TGSI into GLES GLSL. It checks that
  legacy dual-source output avoids explicit MRT locations and extra broadcasts,
  while ordinary output, depth output, and explicit MRT retain their behavior.
- `test-null-blend.c` exercises the renderer's actual shader-key selection and
  null blend-object binding. It includes the implementation to inspect private
  state without adding a production API, and replaces only `glDisable` with a
  recorder so no graphics context is required. It checks GLES and blend-enable
  guards, shader invalidation, and resetting the bound state.

To run against another configured and compiled Meson build:

```sh
python3 tests/run-driver-regressions.py /path/to/build /path/to/test-output -- \
  -L/path/to/epoxy/lib -lepoxy \
  -framework Metal -framework CoreFoundation -lobjc \
  -Wl,-rpath,/path/to/epoxy/lib -Wl,-rpath,/path/to/angle/lib
```

The helper exits nonzero if a test fails. Against an unpatched source build,
translation of the dual-source case and null-object invalidation fail; ordinary,
depth, and MRT checks pass. The shader-key cases run when the new key member is
present, allowing the same test files to demonstrate the baseline failures.

These are source regressions, not complete GPU validation. Runtime acceptance
also needs EGL pixel-readback tests and an application launch through the actual
QEMU/VirGL/ANGLE stack. In particular, shader caches must be exercised across
ordinary/dual-source transitions. Do not treat a guest-only `glGetError()` result
as proof of success: host errors may occur asynchronously.
