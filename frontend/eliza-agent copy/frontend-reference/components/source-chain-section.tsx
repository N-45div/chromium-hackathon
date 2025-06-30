"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Plus } from "lucide-react"

const collateralTokens = [
  {
    symbol: "ETH",
    name: "Ethereum",
    balance: "12.5",
    value: "$31,250.00",
    chain: "Ethereum",
    ratio: "75%",
  },
  {
    symbol: "BNB",
    name: "BNB Chain",
    balance: "45.2",
    value: "$13,981.89",
    chain: "BNB Chain",
    ratio: "65%",
  },
]

export function SourceChainSection() {
  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white flex items-center justify-between">
          Source Chain Collateral
          <Button size="sm" className="bg-teal-600 hover:bg-teal-700">
            <Plus className="w-4 h-4 mr-1" />
            Deposit
          </Button>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {collateralTokens.map((token, index) => (
          <div key={index} className="flex items-center justify-between p-4 bg-slate-700/50 rounded-lg">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-gradient-to-br from-teal-400 to-cyan-400 rounded-full flex items-center justify-center">
                <span className="text-white font-bold text-sm">{token.symbol}</span>
              </div>
              <div>
                <div className="text-white font-medium">
                  {token.balance} {token.symbol}
                </div>
                <div className="text-gray-400 text-sm">{token.value}</div>
              </div>
            </div>
            <div className="text-right">
              <Badge variant="outline" className="border-teal-500 text-teal-400 mb-2">
                {token.chain}
              </Badge>
              <div className="text-sm text-gray-400">Ratio: {token.ratio}</div>
            </div>
          </div>
        ))}

        <div className="pt-4 border-t border-slate-600">
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">Total Collateral Value</span>
            <span className="text-white font-medium">$45,231.89</span>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
