package jfn;

import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.FaultException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

public class Checksum extends JavaService {
  private static String algo = "MD5";

  public String sha256(String s) throws FaultException {
    try {
    MessageDigest md = MessageDigest.getInstance(algo);
    md.update(s.getBytes());
    return md.digest().toString();
    } catch(NoSuchAlgorithmException e) {
        Value msg = Value.create();
        msg.getFirstChild("algo").setValue(algo);
        msg.getFirstChild("message").setValue("The required hashing algorithm is not available");
        throw new FaultException("NoSuchAlgorithm", msg);
    }
  }
}
