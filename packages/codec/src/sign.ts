// @logos-kit/codec/sign: BIP-340 signing for local accounts (Node, browsers,
// React Native). Not QML-safe: @noble/curves needs native BigInt.
import { schnorr } from '@noble/curves/secp256k1.js'
import { type AccountId, publicAccountId } from './account.ts'
import type { Bytes } from './bytes.ts'
import { messageHash, type PublicMessage, type PublicTransaction, type Witness } from './message.ts'

export const publicKeyOf = (secretKey: Bytes): Bytes => schnorr.getPublicKey(secretKey)

export const accountOf = (secretKey: Bytes): AccountId => publicAccountId(publicKeyOf(secretKey))

/** Sign a 32-byte message hash; `auxRand` defaults to fresh randomness. */
export const signHash = (hash: Bytes, secretKey: Bytes, auxRand?: Bytes): Bytes =>
  schnorr.sign(hash, secretKey, auxRand)

export const verifyHash = (signature: Bytes, hash: Bytes, publicKey: Bytes): boolean =>
  schnorr.verify(signature, hash, publicKey)

/** Sign `message` with every key (in the order of its nonces). */
export function signMessage(
  message: PublicMessage,
  secretKeys: Bytes[],
  auxRand?: Bytes,
): PublicTransaction {
  if (secretKeys.length !== message.nonces.length)
    throw new Error(
      `${secretKeys.length} key(s) for ${message.nonces.length} nonce(s): one key per signer`,
    )
  const hash = messageHash(message)
  const witnesses: Witness[] = secretKeys.map((k) => ({
    signature: signHash(hash, k, auxRand),
    publicKey: publicKeyOf(k),
  }))
  return { message, witnesses }
}

export const randomSecretKey = (): Bytes => schnorr.utils.randomSecretKey()
