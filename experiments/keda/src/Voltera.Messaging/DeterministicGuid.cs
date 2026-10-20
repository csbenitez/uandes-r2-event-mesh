using System.Security.Cryptography;
using System.Text;

namespace Voltera.Messaging;

public static class DeterministicGuid
{
    public static Guid Create(params string[] parts)
    {
        var input = string.Join('|', parts);
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        Span<byte> guidBytes = stackalloc byte[16];
        bytes.AsSpan(0, 16).CopyTo(guidBytes);
        return new Guid(guidBytes);
    }
}
