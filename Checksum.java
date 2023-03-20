package jfn;

import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.FaultException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.nio.charset.StandardCharsets;

public class Checksum extends JavaService {
  private static String algo = "sha1";

  // taken from https://stackoverflow.com/a/9855338
  private static final byte[] HEX_ARRAY = "0123456789ABCDEF".getBytes(StandardCharsets.US_ASCII);
  public static String hex(byte[] bytes) {
      byte[] hexChars = new byte[bytes.length * 2];
      for (int j = 0; j < bytes.length; j++) {
          int v = bytes[j] & 0xFF;
          hexChars[j * 2] = HEX_ARRAY[v >>> 4];
          hexChars[j * 2 + 1] = HEX_ARRAY[v & 0x0F];
      }
      return new String(hexChars, StandardCharsets.UTF_8);
  }

  public String sha256(String s) throws FaultException {
    try {
      MessageDigest md = MessageDigest.getInstance(algo);
      md.update(s.getBytes());
      return hex(md.digest());
    } catch(NoSuchAlgorithmException e) {
        Value msg = Value.create();
        msg.getFirstChild("algo").setValue(algo);
        msg.getFirstChild("message").setValue("The required hashing algorithm is not available");
        throw new FaultException("NoSuchAlgorithm", msg);
    }
  }
}
