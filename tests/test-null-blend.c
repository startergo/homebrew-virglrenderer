/* Include the renderer implementation to exercise its private state without
 * adding a production test API or requiring a graphics context. */
#include "vrend/vrend_renderer.c"

static unsigned blend_disables;
static void GLAPIENTRY record_disable(GLenum cap)
{
   if (cap == GL_BLEND)
      blend_disables++;
}

int main(void)
{
   struct vrend_context ctx = {0};
   struct vrend_sub_context sub = {0};
   ctx.sub = &sub;
   sub.blend_state.rt[0].blend_enable = true;
   sub.blend_state.rt[0].rgb_src_factor = PIPE_BLENDFACTOR_SRC1_COLOR;
   sub.shader_dirty = false;
   epoxy_glDisable = record_disable;

#ifdef VIRGL_HAS_DUAL_SOURCE_KEY
   struct vrend_shader_selector fragment = {.type = PIPE_SHADER_FRAGMENT};
   struct vrend_shader_key key = {0};
   vrend_state.use_gles = true;
   vrend_sync_shader_io(&sub, &fragment, &key);
   if (!key.fs.dual_src_blend) {
      fputs("FAIL: enabled GLES dual blending did not select its variant\n", stderr);
      return 1;
   }
   sub.blend_state.rt[0].blend_enable = false;
   vrend_sync_shader_io(&sub, &fragment, &key);
   if (key.fs.dual_src_blend) {
      fputs("FAIL: disabled blending retained the dual-source variant\n", stderr);
      return 1;
   }
   sub.blend_state.rt[0].blend_enable = true;
   sub.blend_state.rt[0].rgb_src_factor = PIPE_BLENDFACTOR_SRC_ALPHA;
   vrend_sync_shader_io(&sub, &fragment, &key);
   if (key.fs.dual_src_blend) {
      fputs("FAIL: ordinary GLES blending selected the dual-source variant\n", stderr);
      return 1;
   }
   sub.blend_state.rt[0].rgb_src_factor = PIPE_BLENDFACTOR_SRC1_COLOR;
   vrend_state.use_gles = false;
   vrend_sync_shader_io(&sub, &fragment, &key);
   if (key.fs.dual_src_blend) {
      fputs("FAIL: desktop GL selected the GLES dual-source variant\n", stderr);
      return 1;
   }
   puts("PASS: blend enable and GLES state select the correct shader variant");
#endif
   vrend_object_bind_blend(&ctx, 0);
   if (!sub.shader_dirty || sub.blend_state.rt[0].blend_enable ||
       sub.blend_state.rt[0].rgb_src_factor || blend_disables != 1) {
      fprintf(stderr, "FAIL: null blend binding did not invalidate the shader and reset blending\n");
      return 1;
   }
   puts("PASS: null blend binding invalidates the shader and resets blending");
   return 0;
}
