import { describe, expect, it } from "vitest";
import { hashPassword as serverHash } from "../../../src/crypto";
import { hashPassword, makeSalt } from "./password";

describe("PBKDF2 password hashing", () => {
  it("matches the shared test vector (apps + API)", async () => {
    expect(await hashPassword("trama123", "AAECAwQFBgcICQoLDA0ODw==")).toBe("zcwRAuc66SSMfJ2S4LMBXmx9ZZUytXkJe52oTpWoI3A=");
  });

  it("agrees with the server implementation for random salts", async () => {
    const salt = makeSalt();
    expect(atob(salt)).toHaveLength(16);
    expect(await hashPassword("contraseña-ñ", salt)).toBe(serverHash("contraseña-ñ", salt));
  });
});
