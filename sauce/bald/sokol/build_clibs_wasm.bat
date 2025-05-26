@echo off

echo log/sokol_log_wasm_gl_release
call emcc -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_log.c

call emar rcs log/sokol_log_wasm_gl_release.a sokol_log.o

echo gfx/sokol_gfx_wasm_gl_release
call emcc -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_gfx.c
call emar rcs gfx/sokol_gfx_wasm_gl_release.a sokol_gfx.o

echo app/sokol_app_wasm_gl_release
call emcc -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_app.c
call emar rcs app/sokol_app_wasm_gl_release.a sokol_app.o

echo glue/sokol_glue_wasm_gl_release
call emcc -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_glue.c
call emar rcs glue/sokol_glue_wasm_gl_release.a sokol_glue.o

echo time/sokol_time_wasm_gl_release
call emcc -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_time.c
call emar rcs time/sokol_time_wasm_gl_release.a sokol_time.o

echo audio/sokol_audio_wasm_gl_release
call emcc -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_audio.c
call emar rcs audio/sokol_audio_wasm_gl_release.a sokol_audio.o

echo debugtext/sokol_debugtext_wasm_gl_release
call emcc -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_debugtext.c
call emar rcs debugtext/sokol_debugtext_wasm_gl_release.a sokol_debugtext.o

echo shape/sokol_shape_wasm_gl_release
call emcc -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_shape.c
call emar rcs shape/sokol_shape_wasm_gl_release.a sokol_shape.o

echo gl/sokol_gl_wasm_gl_release
call emcc -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_gl.c
call emar rcs gl/sokol_gl_wasm_gl_release.a sokol_gl.o

REM Build wasm + GL + Debug
echo log/sokol_log_wasm_gl_debug
call emcc -c -g -DIMPL -DSOKOL_GLES3 c/sokol_log.c
call emar rcs log/sokol_log_wasm_gl_debug.a sokol_log.o

echo gfx/sokol_gfx_wasm_gl_debug
call emcc -c -g -DIMPL -DSOKOL_GLES3 c/sokol_gfx.c
call emar rcs gfx/sokol_gfx_wasm_gl_debug.a sokol_gfx.o

echo app/sokol_app_wasm_gl_debug
call emcc -c -g -DIMPL -DSOKOL_GLES3 c/sokol_app.c
call emar rcs app/sokol_app_wasm_gl_debug.a sokol_app.o

echo glue/sokol_glue_wasm_gl_debug
call emcc -c -g -DIMPL -DSOKOL_GLES3 c/sokol_glue.c
call emar rcs glue/sokol_glue_wasm_gl_debug.a sokol_glue.o

echo time/sokol_time_wasm_gl_debug
call emcc -c -g -DIMPL -DSOKOL_GLES3 c/sokol_time.c
call emar rcs time/sokol_time_wasm_gl_debug.a sokol_time.o

echo audio/sokol_audio_wasm_gl_debug
call emcc -c -g -DIMPL -DSOKOL_GLES3 c/sokol_audio.c
call emar rcs audio/sokol_audio_wasm_gl_debug.a sokol_audio.o

echo debugtext/sokol_debugtext_wasm_gl_debug
call emcc -c -g -DIMPL -DSOKOL_GLES3 c/sokol_debugtext.c
call emar rcs debugtext/sokol_debugtext_wasm_gl_debug.a sokol_debugtext.o

echo shape/sokol_shape_wasm_gl_debug
call emcc -c -g -DIMPL -DSOKOL_GLES3 c/sokol_shape.c
call emar rcs shape/sokol_shape_wasm_gl_debug.a sokol_shape.o

echo gl/sokol_gl_wasm_gl_debug
call emcc -c -g -DIMPL -DSOKOL_GLES3 c/sokol_gl.c
call emar rcs gl/sokol_gl_wasm_gl_debug.a sokol_gl.o