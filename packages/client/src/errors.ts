// Node-side errors. Wallet (LWS-0) errors are `LezError` from @logos-kit/protocol.
export class RpcError extends Error {
  declare readonly code: number
  declare readonly data: unknown
  constructor(code: number, message: string, data?: unknown) {
    super(message)
    this.name = 'RpcError'
    this.code = code
    this.data = data
    Object.setPrototypeOf(this, new.target.prototype)
  }
}

export class HttpError extends Error {
  declare readonly status: number
  constructor(status: number, message: string) {
    super(message)
    this.name = 'HttpError'
    this.status = status
    Object.setPrototypeOf(this, new.target.prototype)
  }
}

export class TimeoutError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'TimeoutError'
    Object.setPrototypeOf(this, new.target.prototype)
  }
}
