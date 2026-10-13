// Recorta um "azulejo" de madeira (arte em fundo branco) num quadrado com cantos transparentes.
// Usado no botão de ouvir (microfone de madeira).
// Uso (PowerShell): Add-Type -Path WoodTileCrop.cs -ReferencedAssemblies System.Drawing
//                   [WoodTileCrop]::Render("arte.png", "saida.png", 512)
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class WoodTileCrop
{
    static bool IsBackground(Color c) { return c.R > 228 && c.G > 228 && c.B > 228; }
    static bool IsWood(Color c) { return c.R - c.B > 40; }

    public static void Render(string src, string output, int size)
    {
        using (var art = new Bitmap(src))
        {
            int cy = art.Height / 2, cx = art.Width / 2;
            int left = 0, right = art.Width - 1, top = 0, bottom = art.Height - 1;
            for (int x = 0; x < art.Width; x++) if (IsWood(art.GetPixel(x, cy))) { left = x; break; }
            for (int x = art.Width - 1; x > left; x--) if (IsWood(art.GetPixel(x, cy))) { right = x; break; }
            // topo/base pela coluna de 1/4 da largura (fora do objeto central)
            int qx = left + (right - left) / 6;
            for (int y = 0; y < art.Height; y++) if (IsWood(art.GetPixel(qx, y))) { top = y; break; }
            for (int y = art.Height - 1; y > top; y--) if (IsWood(art.GetPixel(qx, y))) { bottom = y; break; }
            var tile = Rectangle.FromLTRB(left, top, right + 1, bottom + 1);
            int side = Math.Max(tile.Width, tile.Height);

            using (var sq = new Bitmap(side, side, PixelFormat.Format32bppArgb))
            {
                using (var g = Graphics.FromImage(sq))
                {
                    g.Clear(Color.White);
                    g.DrawImage(art, new Rectangle((side - tile.Width) / 2, (side - tile.Height) / 2, tile.Width, tile.Height), tile, GraphicsUnit.Pixel);
                }
                // Cantos transparentes: preenchimento a partir dos quatro cantos sobre o fundo claro
                var visited = new bool[side, side];
                var stack = new Stack<Point>();
                foreach (var p in new[] { new Point(0, 0), new Point(side - 1, 0), new Point(0, side - 1), new Point(side - 1, side - 1) }) stack.Push(p);
                while (stack.Count > 0)
                {
                    var p = stack.Pop();
                    if (p.X < 0 || p.Y < 0 || p.X >= side || p.Y >= side || visited[p.X, p.Y]) continue;
                    visited[p.X, p.Y] = true;
                    var c = sq.GetPixel(p.X, p.Y);
                    if (c.A != 0 && !(c.R > 190 && c.G > 190 && c.B > 190 && Math.Abs(c.R - c.B) < 30)) continue;
                    sq.SetPixel(p.X, p.Y, Color.Transparent);
                    stack.Push(new Point(p.X + 1, p.Y)); stack.Push(new Point(p.X - 1, p.Y));
                    stack.Push(new Point(p.X, p.Y + 1)); stack.Push(new Point(p.X, p.Y - 1));
                }
                using (var outBmp = new Bitmap(size, size, PixelFormat.Format32bppArgb))
                using (var g = Graphics.FromImage(outBmp))
                {
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.Clear(Color.Transparent);
                    g.DrawImage(sq, 0, 0, size, size);
                    outBmp.Save(output, ImageFormat.Png);
                }
            }
        }
    }
}
