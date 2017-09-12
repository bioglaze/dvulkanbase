\VulkanSDK\1.0.57.0\Bin\glslangValidator.exe -V shader.frag -o shader.frag.spv
\VulkanSDK\1.0.57.0\Bin\glslangValidator.exe -V shader.vert -o shader.vert.spv
\VulkanSDK\1.0.57.0\Bin\glslangValidator -D -V -S vert -e main shader_vert.hlsl -o shader_vert_hlsl.spv
\VulkanSDK\1.0.57.0\Bin\glslangValidator -D -V -S frag -e main shader_frag.hlsl -o shader_frag_hlsl.spv
pause
