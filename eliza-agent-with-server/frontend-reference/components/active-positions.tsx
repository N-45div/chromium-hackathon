"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import { Plus, Minus, AlertTriangle } from "lucide-react"

const positions = [
  {
    id: 1,
    collateralChain: "Ethereum",
    collateralToken: "ETH",
    collateralAmount: "12.5",
    collateralValue: "$31,250",
    borrowChain: "BNB Chain",
    borrowToken: "USDC",
    borrowAmount: "15,420.50",
    healthFactor: 2.45,
    liquidationPrice: "$1,650",
  },
  {
    id: 2,
    collateralChain: "BNB Chain",
    collateralToken: "BNB",
    collateralAmount: "45.2",
    collateralValue: "$13,981",
    borrowChain: "Avalanche",
    borrowToken: "USDC",
    borrowAmount: "8,036.28",
    healthFactor: 1.85,
    liquidationPrice: "$285",
  },
]

export function ActivePositions() {
  const getHealthFactorColor = (factor: number) => {
    if (factor > 2) return "text-green-400"
    if (factor > 1.5) return "text-yellow-400"
    return "text-red-400"
  }

  const getHealthFactorProgress = (factor: number) => {
    return Math.min((factor / 3) * 100, 100)
  }

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Active Positions</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {positions.map((position) => (
            <div key={position.id} className="p-4 bg-slate-700/50 rounded-lg border border-slate-600">
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                {/* Collateral Section */}
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <h4 className="text-white font-medium">Collateral</h4>
                    <Badge variant="outline" className="border-teal-500 text-teal-400">
                      {position.collateralChain}
                    </Badge>
                  </div>
                  <div className="text-sm text-gray-400">
                    {position.collateralAmount} {position.collateralToken}
                  </div>
                  <div className="text-sm text-white font-medium">{position.collateralValue}</div>
                </div>

                {/* Borrowed Section */}
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <h4 className="text-white font-medium">Borrowed</h4>
                    <Badge variant="outline" className="border-orange-500 text-orange-400">
                      {position.borrowChain}
                    </Badge>
                  </div>
                  <div className="text-sm text-gray-400">
                    {position.borrowAmount} {position.borrowToken}
                  </div>
                  <div className="text-sm text-white">Liquidation: {position.liquidationPrice}</div>
                </div>

                {/* Health Factor & Actions */}
                <div className="space-y-3">
                  <div>
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-sm text-gray-400">Health Factor</span>
                      <span className={`text-sm font-medium ${getHealthFactorColor(position.healthFactor)}`}>
                        {position.healthFactor}
                      </span>
                    </div>
                    <Progress value={getHealthFactorProgress(position.healthFactor)} className="h-2" />
                    {position.healthFactor < 1.5 && (
                      <div className="flex items-center mt-1">
                        <AlertTriangle className="w-3 h-3 text-yellow-400 mr-1" />
                        <span className="text-xs text-yellow-400">At Risk</span>
                      </div>
                    )}
                  </div>

                  <div className="flex space-x-2">
                    <Button
                      size="sm"
                      variant="outline"
                      className="flex-1 border-teal-500 text-teal-400 hover:bg-teal-500/10"
                    >
                      <Plus className="w-3 h-3 mr-1" />
                      Add
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="flex-1 border-orange-500 text-orange-400 hover:bg-orange-500/10"
                    >
                      <Minus className="w-3 h-3 mr-1" />
                      Repay
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}
