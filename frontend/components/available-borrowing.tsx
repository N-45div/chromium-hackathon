"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { TrendingUp, TrendingDown } from "lucide-react"

const borrowingOptions = [
  {
    chain: "BNB Chain",
    token: "USDC",
    available: "$18,750.00",
    apy: "8.5%",
    trend: "up",
    capacity: "75%",
  },
  {
    chain: "Avalanche",
    token: "USDC",
    available: "$22,100.00",
    apy: "7.2%",
    trend: "down",
    capacity: "82%",
  },
  {
    chain: "Ethereum",
    token: "USDC",
    available: "$15,420.00",
    apy: "9.1%",
    trend: "up",
    capacity: "68%",
  },
]

export function AvailableBorrowing() {
  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Available Borrowing Capacity</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {borrowingOptions.map((option, index) => (
            <div
              key={index}
              className="p-4 bg-slate-700/50 rounded-lg border border-slate-600 hover:border-teal-500/50 transition-colors"
            >
              <div className="flex items-center justify-between mb-3">
                <Badge variant="outline" className="border-teal-500 text-teal-400">
                  {option.chain}
                </Badge>
                <div className="flex items-center space-x-1">
                  {option.trend === "up" ? (
                    <TrendingUp className="w-4 h-4 text-green-400" />
                  ) : (
                    <TrendingDown className="w-4 h-4 text-red-400" />
                  )}
                  <span className={`text-sm ${option.trend === "up" ? "text-green-400" : "text-red-400"}`}>
                    {option.apy}
                  </span>
                </div>
              </div>

              <div className="space-y-2 mb-4">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Token</span>
                  <span className="text-white">{option.token}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Available</span>
                  <span className="text-white font-medium">{option.available}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Capacity Used</span>
                  <span className="text-teal-400">{option.capacity}</span>
                </div>
              </div>

              <Button size="sm" className="w-full bg-orange-600 hover:bg-orange-700">
                Borrow {option.token}
              </Button>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}
