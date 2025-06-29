"use client"

import type React from "react"

import { useWallet } from "@/hooks/use-wallet"
import { ConnectWalletButton } from "./connect-wallet-button"
import { Wallet } from "lucide-react"

interface WalletGuardProps {
  children: React.ReactNode
}

export function WalletGuard({ children }: WalletGuardProps) {
  const { isConnected } = useWallet()

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900 flex items-center justify-center p-6">
        <div className="text-center max-w-md">
          <div className="w-16 h-16 bg-teal-600/20 rounded-full flex items-center justify-center mx-auto mb-6">
            <Wallet className="w-8 h-8 text-teal-400" />
          </div>
          <h2 className="text-2xl font-bold text-white mb-4">Connect Your Wallet</h2>
          <p className="text-gray-300 mb-8">
            Please connect your wallet to access the StratoLend Network dashboard and start cross-chain lending.
          </p>
          <ConnectWalletButton size="lg" />
        </div>
      </div>
    )
  }

  return <>{children}</>
}
