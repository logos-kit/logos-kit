// The QML bundle's single entry. Shims first: they only add what Qt's V4
// engine lacks (setTimeout, TextEncoder, Promise.allSettled…), never replace.
import { installQmlHost } from './qml-shims.js'

// biome-ignore lint/performance/noBarrelFile: the bundle's single entry
export {
  formatUnits,
  isAccountId,
  nativeTransfer,
  parseUnits,
  TESTIMONIAL_MAX_TEXT,
  TESTIMONIAL_MAX_USERNAME,
  TESTIMONIAL_PROGRAMS,
  TESTIMONIAL_SUBMISSION,
  testimonialPost,
  tokenTransfer,
} from '@logos-kit/codec'
export { CHAINS, ErrorCode, INTENTS, isUserRejection, LezError } from '@logos-kit/protocol'
export { createLogosKit, type LogosKit, type LogosKitHost } from './facade.ts'
export { installQmlHost }
export const VERSION = '0.0.0'
