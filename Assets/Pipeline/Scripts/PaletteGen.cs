using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class PaletteGen : MonoBehaviour
{
    public Texture2D input;

    [SerializeField]
    private List<Color> colors;

    [SerializeField]
    private Texture2D output;

    [SerializeField]
    private Material testMat;

    [ContextMenu("Fuckarooni 2")]
    public void FindOut()
    {
        output = new Texture2D(input.width, input.height, TextureFormat.RGB24, false);
        output.filterMode = FilterMode.Point;

        for (int x = 0; x < input.width; x++)
        {
            for (int y = 0; y < input.height; y++)
            {
                Color c = input.GetPixel(x, y);
                float lightValue = (0.2126f * c.r) + (0.7152f * c.g) + (0.0722f * c.b);
                output.SetPixel(x, y, new Color(lightValue, lightValue, lightValue));
            }
        }

        output.Apply();
        testMat.SetTexture("_MainTex", output);

        byte[] data = output.EncodeToPNG();
        var dirPath = Application.dataPath + "/SaveImages/";
        if (!Directory.Exists(dirPath))
        {
            Directory.CreateDirectory(dirPath);
        }
        File.WriteAllBytes(dirPath + "PaletteSatMask" + ".png", data);
    }

    [ContextMenu("Fuckarooni")]
    public void FuckAround()
    {
        colors = new List<Color>();
        for(int x = 0; x < input.width; x++)
        {
            for(int y = 0; y < input.height; y++)
            {
                Color c = input.GetPixel(x, y);
                if (!colors.Contains(c))
                    colors.Add(c);
            }
        }

        output = new Texture2D(4096, 4096, TextureFormat.RGB24, false);
        output.filterMode = FilterMode.Point;

        int boxOffsetX = 0;
        int boxOffsetY = 0;
        for(int r = 0; r < 256; r++)
        {
            for (int g = 0; g < 256; g++)
            {
                for(int b = 0; b < 256; b++)
                {
                    int pX = g + (boxOffsetX * 256);
                    int pY = b + (boxOffsetY * 256);
                    Color c = GetClosestColor(new Color(r / 255f, g / 255f, b / 255f));
                    output.SetPixel(pX, pY, c);
                }
            }
            boxOffsetX++;
            if (boxOffsetX > 15)
            {
                boxOffsetX = 0;
                boxOffsetY++;
            }
        }

        //for (int g = 0; g < 256; g++)
        //{
        //    for (int b = 0; b < 256; b++)
        //    {
        //        int pX = g + (15 * 255) + 1;
        //        int pY = b + (15 * 255) + 1;
        //        Color c = new Color(1, g / 255f, b / 255f);
        //        output.SetPixel(pX, pY, c);
        //    }
        //}

        output.Apply();
        testMat.SetTexture("_MainTex", output);

        byte[] data = output.EncodeToPNG();
        var dirPath = Application.dataPath + "/SaveImages/";
        if (!Directory.Exists(dirPath))
        {
            Directory.CreateDirectory(dirPath);
        }
        File.WriteAllBytes(dirPath + "PaletteFinal" + ".png", data);
    }

    Color GetClosestColor(Color inC)
    {
        Vector3 a = new Vector3(inC.r, inC.g, inC.b);

        float smallestDist = 5;
        Color outColor = Color.black;
        foreach(Color cP in colors)
        {
            Vector3 b = new Vector3(cP.r, cP.g, cP.b);
            float d = Vector3.Distance(a, b);
            if (d < smallestDist)
            {
                outColor = cP;
                smallestDist = d;
            }
        }

        return outColor;
    }
}
