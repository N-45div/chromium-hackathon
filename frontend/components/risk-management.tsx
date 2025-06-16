"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Switch } from "@/components/ui/switch"
import { Label } from "@/components/ui/label"
import { Progress } from "@/components/ui/progress"
import { Shield, AlertTriangle, Bell } from "lucide-react"
import { useState } from "react"

export function RiskManagement() {
  const [autoProtection, setAutoProtection] = useState(true)
  const [liquidationAlerts, setLiquidationAlerts] = useState(true)
  const [marketAlerts, setMarketAlerts] = useState(false)

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white flex items-center">
          <Shield className="w-5 h-5 mr-2 text-teal-400" />
          Risk Management
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-4">
          <h4 className="text-white font-medium">Current Collateral Ratios</h4>
          <div className="space-y-3">
            <div>
              <div className="flex justify-between text-sm mb-1">
                <span className="text-gray-400">ETH Position</span>
                <span className="text-green-400">75% (Safe)</span>
              </div>
              <Progress value={75} className="h-2" />
            </div>
            <div>
              <div className="flex justify-between text-sm mb-1">
                <span className="text-gray-400">BNB Position</span>
                <span className="text-yellow-400">65% (Moderate)</span>
              </div>
              <Progress value={65} className="h-2" />
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <h4 className="text-white font-medium">Liquidation Risk Indicators</h4>
          <div className="grid grid-cols-2 gap-3">
            <div className="p-3 bg-slate-700/50 rounded-lg text-center">
              <div className="text-lg font-bold text-green-400">2.45</div>
              <div className="text-xs text-gray-400">Health Factor</div>
            </div>
            <div className="p-3 bg-slate-700/50 rounded-lg text-center">
              <div className="text-lg font-bold text-white">$1,650</div>
              <div className="text-xs text-gray-400">Liquidation Price</div>
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <h4 className="text-white font-medium">Automated Protection</h4>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="space-y-1">
                <Label htmlFor="auto-protection" className="text-sm text-white">
                  Auto-Repay Protection
                </Label>
                <p className="text-xs text-gray-400">Automatically repay loans when health factor drops below 1.5</p>
              </div>
              <Switch id="auto-protection" checked={autoProtection} onCheckedChange={setAutoProtection} />
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h4 className="text-white font-medium">Alert Preferences</h4>
            <Button variant="outline" size="sm" className="border-slate-600 text-gray-300 hover:bg-slate-700">
              <Bell className="w-4 h-4 mr-1" />
              Configure
            </Button>
          </div>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <Label htmlFor="liquidation-alerts" className="text-sm text-white">
                Liquidation Warnings
              </Label>
              <Switch id="liquidation-alerts" checked={liquidationAlerts} onCheckedChange={setLiquidationAlerts} />
            </div>
            <div className="flex items-center justify-between">
              <Label htmlFor="market-alerts" className="text-sm text-white">
                Market Opportunity Alerts
              </Label>
              <Switch id="market-alerts" checked={marketAlerts} onCheckedChange={setMarketAlerts} />
            </div>
          </div>
        </div>

        <div className="p-3 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
          <div className="flex items-start space-x-2">
            <AlertTriangle className="w-4 h-4 text-yellow-400 mt-0.5" />
            <div>
              <p className="text-sm text-yellow-300 font-medium">Risk Alert</p>
              <p className="text-xs text-yellow-200">
                ETH price volatility increased by 15% in the last 24h. Consider adding collateral.
              </p>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
