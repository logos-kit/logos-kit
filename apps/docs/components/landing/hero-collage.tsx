import Image from 'next/image'

/**
 * The hero's product shot: a Basecamp app after a post landed, with the
 * wallet's sheets on top of it: the approval the user read, and a private
 * transfer proving. All real captures (public/shots, `pnpm shots`).
 */
export function HeroCollage() {
  return (
    <div className="relative aspect-[16/10] w-full overflow-hidden bg-black">
      {/* The app, cropped to its content (the Basecamp sidebar of a dev install shows placeholder initials). */}
      <Image
        src="/shots/testimonial-basecamp.webp"
        alt="Logos Kit Testimonials in Basecamp after a post landed on chain"
        width={2000}
        height={1089}
        priority
        className="absolute top-0 left-[-6%] h-auto w-[112%] max-w-none opacity-80"
      />
      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(90deg,#000_0%,transparent_22%,transparent_60%,rgb(0_0_0/0.85)_100%)]" />
      <div className="absolute top-[7%] right-[4%] w-[27%] overflow-hidden rounded-[18px] border border-white/10 bg-black p-1.5 shadow-[0_30px_80px_-10px_rgb(0_0_0/0.9)] md:rounded-[22px]">
        <Image
          src="/shots/wallet-approval.webp"
          alt="The wallet's approval sheet for the post"
          width={840}
          height={1340}
          className="h-auto w-full"
        />
      </div>
      <div className="absolute bottom-[-6%] left-[4%] w-[22%] overflow-hidden rounded-[18px] border border-white/10 bg-black p-1.5 shadow-[0_30px_80px_-10px_rgb(0_0_0/0.9)] md:rounded-[22px]">
        <Image
          src="/shots/wallet-proving.webp"
          alt="A private transfer proving in the wallet"
          width={920}
          height={1248}
          className="h-auto w-full"
        />
      </div>
    </div>
  )
}
