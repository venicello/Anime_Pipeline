using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class PaletteApplier : MonoBehaviour
{
    public Shader shader;
    public Texture paletteTex;
    Material mat;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if(mat == null)
        {
            ReupMat();
        }

        Graphics.Blit(source, destination, mat);
    }

    [ContextMenu("Reup")]
    private void ReupMat()
    {
        mat = new Material(shader);
        mat.SetTexture("_PaletteTex", paletteTex);
    }
}
