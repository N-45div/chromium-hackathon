import type React from "react"
import type { Metadata } from "next"
import { Inter } from "next/font/google"
import "./globals.css"
import { Navigation } from "@/components/navigation"
import { Toaster } from "@/components/ui/toaster"

import { SolanaProvider } from "@/components/solana-provider";
import "@solana/wallet-adapter-react-ui/styles.css";

const inter = Inter({ subsets: ["latin"] })

export const metadata: Metadata = {
  title: "StratoLend Network - Cross-Chain Lending Reimagined",
  description:
    "Deposit collateral on one chain, borrow on another. Maximize your capital efficiency across blockchain ecosystems.",
    generator: 'v0.dev'
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <SolanaProvider>
          <Navigation />
          <main>{children}</main>
          <Toaster />
        </SolanaProvider>
      </body>
    </html>
  )
}
