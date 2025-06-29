"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { ArrowDownLeft, RefreshCw } from "lucide-react"

const borrowedTokens = [
  {
    symbol: "USDC",
    name: "USD Coin",
    borrowed: "15,420.50",
    value: "$15,420.50",
    chain: "BNB Chain",
    apy: "8.5%",
  },
  {
    symbol: "USDC",
    name: "USD Coin",
    borrowed: "8,036.28",
    value: "$8,036.28",
    chain: "Avalanche",
    apy: "7.2%",
  },
]

export function TargetChainSection() {
  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white flex items-center justify-between">
          Target Chain Borrowing
          <Button size="sm" className="bg-orange-600 hover:bg-orange-700">
            <ArrowDownLeft className="w-4 h-4 mr-1" />
            Borrow
          </Button>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {borrowedTokens.map((token, index) => (
          <div key={index} className="flex items-center justify-between p-4 bg-slate-700/50 rounded-lg">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-gradient-to-br from-orange-400 to-red-400 rounded-full flex items-center justify-center">
                <span className="text-white font-bold text-sm">{token.symbol}</span>
              </div>
              <div>
                <div className="text-white font-medium">
                  {token.borrowed} {token.symbol}
                </div>
                <div className="text-gray-400 text-sm">{token.value}</div>
              </div>
            </div>
            <div className="text-right">
              <Badge variant="outline" className="border-orange-500 text-orange-400 mb-2">
                {token.chain}
              </Badge>
              <div className="text-sm text-gray-400">APY: {token.apy}</div>
            </div>
          </div>
        ))}

        <div className="pt-4 border-t border-slate-600 space-y-2">
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">Total Borrowed</span>
            <span className="text-white font-medium">$23,456.78</span>
          </div>
          <Button variant="outline" size="sm" className="w-full border-slate-600 text-gray-300 hover:bg-slate-700">
            <RefreshCw className="w-4 h-4 mr-2" />
            Repay Loans
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
