"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { TrendingUp, TrendingDown, BarChart3 } from "lucide-react"

const marketData = [
  {
    chain: "Ethereum",
    borrowApy: "9.1%",
    supplyApy: "5.2%",
    utilization: "78%",
    volume24h: "$2.4M",
    trend: "up",
  },
  {
    chain: "BNB Chain",
    borrowApy: "8.5%",
    supplyApy: "4.8%",
    utilization: "82%",
    volume24h: "$1.8M",
    trend: "up",
  },
  {
    chain: "Avalanche",
    borrowApy: "7.2%",
    supplyApy: "4.1%",
    utilization: "65%",
    volume24h: "$1.2M",
    trend: "down",
  },
]

export function MarketOverview() {
  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white flex items-center">
          <BarChart3 className="w-5 h-5 mr-2 text-teal-400" />
          Market Overview
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {marketData.map((market, index) => (
            <div key={index} className="p-4 bg-slate-700/50 rounded-lg border border-slate-600">
              <div className="flex items-center justify-between mb-3">
                <Badge variant="outline" className="border-teal-500 text-teal-400">
                  {market.chain}
                </Badge>
                <div className="flex items-center space-x-1">
                  {market.trend === "up" ? (
                    <TrendingUp className="w-4 h-4 text-green-400" />
                  ) : (
                    <TrendingDown className="w-4 h-4 text-red-400" />
                  )}
                </div>
              </div>

              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Borrow APY</span>
                  <span className="text-orange-400 font-medium">{market.borrowApy}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Supply APY</span>
                  <span className="text-teal-400 font-medium">{market.supplyApy}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Utilization</span>
                  <span className="text-white">{market.utilization}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">24h Volume</span>
                  <span className="text-white">{market.volume24h}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}
