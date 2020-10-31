import core.simd;
import std.math: abs, approxEqual, cos, isNaN, PI, sin, tan;
import std.string;
//import vec3;

void multiply( Matrix4x4 ma, Matrix4x4 mb, out Matrix4x4 result )
{
    float4 a_line, b_line, r_line;

    for (int i = 0; i < 16; i += 4)
    {
        a_line.ptr[ 0 ] = mb.m[ 0 ];
        a_line.ptr[ 1 ] = mb.m[ 1 ];
        a_line.ptr[ 2 ] = mb.m[ 2 ];
        a_line.ptr[ 3 ] = mb.m[ 3 ];
        b_line = ma.m[ i ];
        r_line = cast(float4)( __simd( XMM.MULPS, a_line, b_line ) );
        
        for (int j = 1; j < 4; j++)
        {
            a_line.ptr[ 0 ] = mb.m[ j * 4 + 0 ];
            a_line.ptr[ 1 ] = mb.m[ j * 4 + 1 ];
            a_line.ptr[ 2 ] = mb.m[ j * 4 + 2 ];
            a_line.ptr[ 3 ] = mb.m[ j * 4 + 3 ];
            
            b_line = ma.m[ i + j ];
            r_line = cast( float4 )( __simd( XMM.ADDPS, __simd( XMM.MULPS, a_line, b_line ), r_line ) );
        }

        result.m[ i + 0 ] = r_line.ptr[ 0 ];
        result.m[ i + 1 ] = r_line.ptr[ 1 ];
        result.m[ i + 2 ] = r_line.ptr[ 2 ];
        result.m[ i + 3 ] = r_line.ptr[ 3 ];
    }
}

void makeProjection( float left, float right, float bottom, float top, float nearDepth, float farDepth, out Matrix4x4 result )
{
    const float tx = -((right + left) / (right - left));
    const float ty = -((bottom + top) / (bottom - top));
    const float tz = nearDepth / (nearDepth - farDepth);

    result.m =
      [
       2.0f / (right - left), 0.0f, 0.0f, 0.0f,
       0.0f, 2.0f / (bottom - top), 0.0f, 0.0f,
       0.0f, 0.0f, 1.0f / (nearDepth - farDepth), 0.0f,
       tx, ty, tz, 1.0f
       ];
}

public align(16) struct Matrix4x4
{
    public void initFrom( float[] data )
    {
        m = data;
    }
  
    float[ 16 ] m;
}

unittest
{
    Matrix4x4 matrix1;
    float[] m1data = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 ];
    matrix1.initFrom( m1data );

    Matrix4x4 matrix2;
    float[] m2data = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 ];
    matrix2.initFrom( m2data );

    Matrix4x4 result;
    multiply( matrix1, matrix2, result );

    Matrix4x4 expectedResult;
    float[] exData = 
        [ 
            90, 100, 110, 120,
            202, 228, 254, 280,
            314, 356, 398, 440,
            426, 484, 542, 600
        ];
    expectedResult.initFrom( exData );

    for (int i = 0; i < 16; ++i)
    {
        if (abs( result.m[ i ] - expectedResult.m[ i ] ) > 0.0001f)
        {
            assert( false, "Matrix multiply test failed!" );
        }
    }
}
