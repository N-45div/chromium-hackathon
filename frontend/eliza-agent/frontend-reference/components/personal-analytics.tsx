"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { TrendingUp, Calendar, Target } from "lucide-react"

export function PersonalAnalytics() {
  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white flex items-center">
          <TrendingUp className="w-5 h-5 mr-2 text-teal-400" />
          Personal Analytics
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="grid grid-cols-2 gap-4">
          <div className="text-center p-3 bg-slate-700/50 rounded-lg">
            <div className="text-2xl font-bold text-teal-400">+12.5%</div>
            <div className="text-sm text-gray-400">Total Yield</div>
          </div>
          <div className="text-center p-3 bg-slate-700/50 rounded-lg">
            <div className="text-2xl font-bold text-white">89 days</div>
            <div className="text-sm text-gray-400">Avg Position</div>
          </div>
        </div>

        <div className="space-y-3">
          <h4 className="text-white font-medium">Historical Performance</h4>
          <div className="h-32 bg-slate-700/30 rounded-lg flex items-center justify-center">
            <span className="text-gray-400">Performance Chart Placeholder</span>
          </div>
        </div>

        <div className="space-y-3">
          <h4 className="text-white font-medium">Risk Exposure Over Time</h4>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Current Risk Level</span>
              <span className="text-green-400">Low</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Max Risk (30d)</span>
              <span className="text-yellow-400">Medium</span>
            </div>
          </div>
        </div>

        <div className="space-y-3">
          <h4 className="text-white font-medium">Yield Optimization</h4>
          <div className="p-3 bg-teal-600/10 border border-teal-500/30 rounded-lg">
            <div className="flex items-start space-x-2">
              <Target className="w-4 h-4 text-teal-400 mt-0.5" />
              <div>
                <p className="text-sm text-teal-300 font-medium">Optimization Suggestion</p>
                <p className="text-xs text-teal-200">
                  Consider moving 25% of ETH collateral to Avalanche for +2.3% APY
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h4 className="text-white font-medium">Transaction History</h4>
            <Button variant="outline" size="sm" className="border-slate-600 text-gray-300 hover:bg-slate-700">
              <Calendar className="w-4 h-4 mr-1" />
              View All
            </Button>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between items-center p-2 bg-slate-700/30 rounded">
              <div>
                <div className="text-sm text-white">Deposited 5.0 ETH</div>
                <div className="text-xs text-gray-400">Ethereum → BNB Chain</div>
              </div>
              <div className="text-xs text-gray-400">2 days ago</div>
            </div>
            <div className="flex justify-between items-center p-2 bg-slate-700/30 rounded">
              <div>
                <div className="text-sm text-white">Borrowed 8,500 USDC</div>
                <div className="text-xs text-gray-400">BNB Chain</div>
              </div>
              <div className="text-xs text-gray-400">3 days ago</div>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
