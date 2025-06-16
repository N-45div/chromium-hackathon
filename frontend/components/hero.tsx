"use client"

import { Button } from "@/components/ui/button"
import { ConnectWalletButton } from "./connect-wallet-button"
import { ArrowRight, Zap } from "lucide-react"
import Link from "next/link"

export function Hero() {
  return (
    <div className="relative overflow-hidden">
      {/* Animated background */}
      <div className="absolute inset-0 bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900">
        <div className="absolute inset-0 bg-[url('/placeholder.svg?height=800&width=1200')] opacity-10 bg-cover bg-center" />
        <div className="absolute inset-0 bg-gradient-to-t from-slate-900/50 to-transparent" />
      </div>

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-32">
        <div className="text-center">
          <div className="flex justify-center mb-6">
            <div className="flex items-center space-x-2 bg-teal-600/20 backdrop-blur-sm border border-teal-500/30 rounded-full px-4 py-2">
              <Zap className="w-4 h-4 text-teal-400" />
              <span className="text-teal-300 text-sm font-medium">Cross-Chain Protocol</span>
            </div>
          </div>

          <h1 className="text-4xl md:text-6xl lg:text-7xl font-bold text-white mb-6 leading-tight">
            Cross-Chain Lending
            <span className="block bg-gradient-to-r from-teal-400 to-cyan-400 bg-clip-text text-transparent">
              Reimagined
            </span>
          </h1>

          <p className="text-xl md:text-2xl text-gray-300 mb-12 max-w-4xl mx-auto leading-relaxed">
            Deposit collateral on one chain, borrow on another. Maximize your capital efficiency across blockchain
            ecosystems with institutional-grade security.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
            <ConnectWalletButton size="lg" className="text-lg px-8 py-4" />
            <Link href="/dashboard">
              <Button
                variant="outline"
                size="lg"
                className="text-lg px-8 py-4 border-teal-500 text-teal-400 hover:bg-teal-500/10"
              >
                Explore Dashboard
                <ArrowRight className="ml-2 w-5 h-5" />
              </Button>
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}
