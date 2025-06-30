"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { TrendingUp, ArrowRight } from "lucide-react"

const opportunities = [
  {
    sourceChain: "Ethereum",
    targetChain: "Avalanche",
    collateral: "ETH",
    borrowToken: "USDC",
    apy: "14.2%",
    risk: "Low",
    available: "$125,000",
  },
  {
    sourceChain: "BNB Chain",
    targetChain: "Ethereum",
    collateral: "BNB",
    borrowToken: "USDC",
    apy: "11.8%",
    risk: "Medium",
    available: "$89,500",
  },
  {
    sourceChain: "Avalanche",
    targetChain: "BNB Chain",
    collateral: "AVAX",
    borrowToken: "USDC",
    apy: "13.5%",
    risk: "Low",
    available: "$67,200",
  },
]

export function CrossChainOpportunities() {
  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white flex items-center">
          <TrendingUp className="w-5 h-5 mr-2 text-teal-400" />
          Cross-Chain Opportunities
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {opportunities.map((opportunity, index) => (
            <div
              key={index}
              className="p-4 bg-slate-700/50 rounded-lg border border-slate-600 hover:border-teal-500/50 transition-colors"
            >
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center space-x-2">
                  <span className="text-sm text-gray-400">{opportunity.sourceChain}</span>
                  <ArrowRight className="w-4 h-4 text-gray-500" />
                  <span className="text-sm text-gray-400">{opportunity.targetChain}</span>
                </div>
                <Badge
                  variant="outline"
                  className={
                    opportunity.risk === "Low" ? "border-green-500 text-green-400" : "border-yellow-500 text-yellow-400"
                  }
                >
                  {opportunity.risk}
                </Badge>
              </div>

              <div className="space-y-2 mb-4">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Collateral</span>
                  <span className="text-white">{opportunity.collateral}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Borrow</span>
                  <span className="text-white">{opportunity.borrowToken}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">APY</span>
                  <span className="text-teal-400 font-medium">{opportunity.apy}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Available</span>
                  <span className="text-white">{opportunity.available}</span>
                </div>
              </div>

              <Button size="sm" className="w-full bg-teal-600 hover:bg-teal-700">
                Start Lending
              </Button>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}
