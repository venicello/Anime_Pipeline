# Anime_Pipeline
WIP Unity shader setup for retro anime-styled cel shading.

This is still a pretty rough take on the concept, but it has a few key features I'm excited about.
The whole thing uses the built-in deferred rendering pipeline, which is great for general lighting features - we get much better performance with higher numbers of pixel lights, and we don't have to deal with the mess that is HDRP when we want to customize a feature.

The 'cel' look consists of two processes. One takes place within the deferred lighting function, and one takes place in a post-processing shader.  Both use features of the deferred pipeline.

First, we use a custom "standard" shader with a number of features stripped out.  This cel shading setup is meant to mimic flatter, less digital shading, so we don't support metallic / roughness.  Normal maps currently aren't supported because I was intending this project to use a lower-poly style, but adding them wouldn't break anything. This shader has a custom 'cel mask' value that is used later.

The standard shader has its own custom deferred input CGinclude. this lets us put the 'cel mask' into one of the unused deferred buffer channels (in our case, the unused 2-bit channel in gbuffer2).

Then, in an unrelated process, we run our deferred lighting calculations (found in BRDFCustom.cginc).  We override the default deferred lighting function here, snapping the light vector into bands based on its visual luminance. This gives us a very standard video-game cel shading look.

Once lighting calculations are done, we move to post-processing.  The shader here converts our scene to use a fixed set of colors using a 3D LUT.  This is intended to mimic the process of painting actual cels - anime studios had fixed palettes of cel paint, and characters would be animated with this palette to make their colors consistent from frame to frame.  The cel palette included in this project is based on an old cel paint catalogue I found online.  It's a little dark and saturated right now, and needs some work in the palette generator to improve the color balance, but it makes the colors much more consistent under different colors / levels of light.

The 'cel mask' is pulled for use in this postprocessing shader - as backgrounds in old anime weren't painted with the cel palette, we want to mask those out. The postprocessing shader just lerps between the adjusted output and the base output based on the mask.