using Godot;
using Godot.Collections;

[Tool]
[GlobalClass]
public partial class CSharpMesh : PrimitiveMesh
{
    private static readonly Vector3[] Directions = {
        Vector3.Up,
        Vector3.Down,
        Vector3.Left,
        Vector3.Right,
        Vector3.Forward,
        Vector3.Back,
    };

    private int _resolution = 10;

    [Export(PropertyHint.Range, "2,4096")]
    public int Resolution
    {
        get
        {
            return _resolution;
        }
        set
        {
            _resolution = Mathf.Clamp(value, 2, 4096);
            RequestUpdate();
            EmitChanged();
        }
    }

    private float _radius = 1.0f;

    [Export(PropertyHint.Range, "0,100,or_greater,suffix:m")]
    public float Radius
    {
        get
        {
            return _radius;
        }
        set
        {
            _radius = Mathf.Max(value, 0.0f);
            RequestUpdate();
            EmitChanged();
        }
    }

    private Noise _continentNoise = null;

    [Export]
    public Noise ContinentNoise
    {
        get
        {
            return _continentNoise;
        }
        set
        {
            _continentNoise = value;
            RequestUpdate();
            EmitChanged();
        }
    }

    private Noise _rigdesNoise = null;

    [Export]
    public Noise RidgesNoise
    {
        get
        {
            return _rigdesNoise;
        }
        set
        {
            _rigdesNoise = value;
            RequestUpdate();
            EmitChanged();
        }
    }

    private Gradient _planetColors = null;

    [Export]
    public Gradient PlanetColors
    {
        get
        {
            return _planetColors;
        }
        set
        {
            _planetColors = value;
            RequestUpdate();
            EmitChanged();
        }
    }

    private bool _generateNormals = false;

    [Export]
    public bool GenerateNormals
    {
        get
        {
            return _generateNormals;
        }
        set
        {
            _generateNormals = value;
            RequestUpdate();
            EmitChanged();
        }
    }

    [Export(PropertyHint.None, "suffix:ms")]
    private float _generationTime = 0.0f;

    public override Array _CreateMeshArray()
    {
        var time = Time.GetTicksMsec();
        // Allocate space for the mesh arrays
        var meshArray = new Array();
        meshArray.Resize((int)ArrayType.Max);
        var vertices = new Vector3[Resolution * Resolution * 6];
        var indices = new int[(Resolution - 1) * (Resolution - 1) * 36];
        var triangleIndex = 0;
        var normals = new Vector3[vertices.Length];
        var uvs = new Vector2[vertices.Length];
        var colors = new Color[vertices.Length];
        // Generate all faces one by one
        for (int f = 0; f < Directions.Length; f++)
        {
            var localUp = Directions[f];
            var axisA = new Vector3(localUp.Y, localUp.Z, localUp.X);
            var axisB = localUp.Cross(axisA);
            for (int y = 0; y < Resolution; y++)
            {
                for (int x = 0; x < Resolution; x++)
                {
                    // Generate the vertex position
                    var vertexIndex = Resolution * Resolution * f + x + y * Resolution;
                    uvs[vertexIndex] = new Vector2(x, y) / (Resolution - 1);
                    normals[vertexIndex] = (localUp + (uvs[vertexIndex].X - 0.5f) * 2.0f * axisB + (uvs[vertexIndex].Y - 0.5f) * 2.0f * axisA).Normalized();
                    vertices[vertexIndex] = normals[vertexIndex] * Radius;
                    // Add noise to the vertex position
                    if (IsInstanceValid(ContinentNoise))
                    {
                        var noiseMask = ContinentNoise.GetNoise3Dv(vertices[vertexIndex]);
                        var planetNoise = noiseMask;
                        if (IsInstanceValid(RidgesNoise))
                        {
                            planetNoise += RidgesNoise.GetNoise3Dv(vertices[vertexIndex]) * noiseMask;
                            vertices[vertexIndex] += normals[vertexIndex] * planetNoise;
                        }
                        // Add vertex colors based on the height of the planet
                        if (IsInstanceValid(PlanetColors))
                        {
                            colors[vertexIndex] = PlanetColors.Sample(planetNoise);
                        }
                        else
                        {
                            colors[vertexIndex] = new Color(1.0f, 1.0f, 1.0f);
                        }
                    }
                    // Generate indices
                    if (x != Resolution - 1 && y != Resolution - 1)
                    {
                        indices[triangleIndex] = vertexIndex;
                        indices[triangleIndex + 1] = vertexIndex + Resolution + 1;
                        indices[triangleIndex + 2] = vertexIndex + Resolution;
                        indices[triangleIndex + 3] = vertexIndex;
                        indices[triangleIndex + 4] = vertexIndex + 1;
                        indices[triangleIndex + 5] = vertexIndex + Resolution + 1;
                        triangleIndex += 6;
                    }
                }
            }
        }
        // Commit the result
        meshArray[(int)ArrayType.Vertex] = vertices;
        meshArray[(int)ArrayType.Index] = indices;
        meshArray[(int)ArrayType.Normal] = normals;
        meshArray[(int)ArrayType.TexUV] = uvs;
        meshArray[(int)ArrayType.Color] = colors;
        // Generating normals using the SurfaceTool requires all vertices to be generated
        if (GenerateNormals)
        {
            var surfaceTool = new SurfaceTool();
            surfaceTool.CreateFromArrays(meshArray);
            surfaceTool.GenerateNormals();
            meshArray = surfaceTool.CommitToArrays();
        }
        _generationTime = Time.GetTicksMsec() - time;
        return meshArray;
    }

    public override void _ValidateProperty(Dictionary property)
    {
        if (property["name"].AsStringName() == PropertyName._generationTime)
        {
            property["usage"] = (int)(PropertyUsageFlags.ReadOnly | PropertyUsageFlags.Editor);
        }
        base._ValidateProperty(property);
    }
}
