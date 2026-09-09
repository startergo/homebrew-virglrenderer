/* Offline regression for GLES fragment output translation. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tgsi/tgsi_text.h"
#include "vrend_shader.h"
#include "vrend_strbuf.h"

static int convert(const char *name, const char *text, int dual)
{
   struct tgsi_token tokens[512];
   struct vrend_shader_cfg cfg = {
      .glsl_version = 300,
      .max_draw_buffers = 8,
      .use_gles = 1,
      .has_dual_src_blend = 1,
   };
   struct vrend_shader_key key = {0};
#ifdef VIRGL_HAS_DUAL_SOURCE_KEY
   key.fs.dual_src_blend = dual;
#else
   (void)dual;
#endif
   struct vrend_shader_info info = {0};
   struct vrend_variable_shader_info variable_info = {0};
   struct vrend_strarray output = {0};
   if (!tgsi_text_translate(text, tokens, 512)) {
      printf("FAIL: %s TGSI parsing\n", name);
      return 1;
   }
   if (!strarray_alloc(&output, 3) ||
       !vrend_convert_shader(NULL, &cfg, tokens, 0, &key, &info,
                             &variable_info, &output)) {
      printf("FAIL: %s translation\n", name);
      return 1;
   }

   char combined[32768] = {0};
   for (int i = 0; i < output.num_strings; i++)
      strncat(combined, output.strings[i].buf,
              sizeof(combined) - strlen(combined) - 1);

   bool ok = false;
   if (!strcmp(name, "dual")) {
      ok = strstr(combined, "fsout_c0") && strstr(combined, "fsout_c1") &&
           !strstr(combined, "layout (location=") &&
           !strstr(combined, "fsout_c2");
   } else if (!strcmp(name, "ordinary_same_shader")) {
      ok = strstr(combined, "layout (location=7)") &&
           strstr(combined, "fsout_c7 = fsout_c0;");
   } else if (!strcmp(name, "broadcast_depth")) {
      ok = strstr(combined, "layout (location=7)") &&
           strstr(combined, "gl_FragDepth =") &&
           strstr(combined, "fsout_c7 = fsout_c0;");
   } else if (!strcmp(name, "mrt")) {
      ok = strstr(combined, "fsout_c0") && strstr(combined, "fsout_c1") &&
           !strstr(combined, "fsout_c2");
   }
   printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
   strarray_free(&output, true);
   return ok ? 0 : 1;
}

int main(void)
{
   const char *dual =
      "FRAG\n"
      "PROPERTY FS_COLOR0_WRITES_ALL_CBUFS 1\n"
      "DCL OUT[0], COLOR\nDCL OUT[1], COLOR[1]\n"
      "IMM[0] FLT32 {0.8,0.4,0.2,0.5}\n"
      "IMM[1] FLT32 {0.25,0.5,0.75,0.6}\n"
      "MOV OUT[0], IMM[0]\nMOV OUT[1], IMM[1]\nEND\n";
   const char *depth =
      "FRAG\n"
      "PROPERTY FS_COLOR0_WRITES_ALL_CBUFS 1\n"
      "DCL OUT[0], COLOR\nDCL OUT[1], POSITION\n"
      "IMM[0] FLT32 {0.8,0.4,0.2,0.5}\n"
      "MOV OUT[0], IMM[0]\nMOV OUT[1].z, IMM[0].wwww\nEND\n";
   const char *mrt =
      "FRAG\nDCL OUT[0], COLOR\nDCL OUT[1], COLOR[1]\n"
      "IMM[0] FLT32 {0.8,0.4,0.2,0.5}\n"
      "IMM[1] FLT32 {0.25,0.5,0.75,0.6}\n"
      "MOV OUT[0], IMM[0]\nMOV OUT[1], IMM[1]\nEND\n";
   return convert("dual", dual, 1) |
          convert("ordinary_same_shader", dual, 0) |
          convert("broadcast_depth", depth, 0) |
          convert("mrt", mrt, 0);
}
