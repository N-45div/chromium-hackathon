"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { useState } from "react"
import { useToast } from "@/hooks/use-toast"
import { AlertTriangle } from "lucide-react"

const collateralPositions = [
  { token: "ETH", amount: "12.5", value: "$31,250", available: "8.2" },
  { token: "BNB", amount: "45.2", value: "$13,981", available: "25.1" },
]

export function WithdrawCollateral() {
  const [selectedToken, setSelectedToken] = useState("")
  const [amount, setAmount] = useState("")
  const { toast } = useToast()

  const handleWithdraw = () => {
    if (!selectedToken || !amount) {
      toast({
        title: "Error",
        description: "Please select a token and enter an amount",
        variant: "destructive",
      })
      return
    }

    toast({
      title: "Withdrawal Initiated",
      description: `Withdrawing ${amount} ${selectedToken} collateral`,
    })
  }

  const selectedPosition = collateralPositions.find((p) => p.token === selectedToken)
  const impactOnBorrowing = amount ? (Number.parseFloat(amount) * 0.75 * 2500).toFixed(0) : "0"

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Withdraw Collateral</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-2">
          <Label className="text-gray-300">Collateral Token</Label>
          <Select value={selectedToken} onValueChange={setSelectedToken}>
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue placeholder="Select collateral to withdraw" />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              {collateralPositions.map((position) => (
                <SelectItem key={position.token} value={position.token} className="text-white hover:bg-slate-600">
                  <div className="flex items-center justify-between w-full">
                    <span>{position.token}</span>
                    <span className="text-gray-400 ml-2">{position.amount} available</span>
                  </div>
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label className="text-gray-300">Amount</Label>
          <div className="relative">
            <Input
              type="number"
              placeholder="0.0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="bg-slate-700 border-slate-600 text-white pr-16"
            />
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="absolute right-2 top-1/2 transform -translate-y-1/2 text-teal-400 hover:text-teal-300"
              onClick={() => selectedPosition && setAmount(selectedPosition.available)}
            >
              MAX
            </Button>
          </div>
          {selectedPosition && (
            <p className="text-sm text-gray-400">
              Available: {selectedPosition.available} {selectedToken}
            </p>
          )}
        </div>

        {selectedToken && amount && (
          <div className="space-y-4">
            <div className="p-4 bg-slate-700/50 rounded-lg space-y-2">
              <h4 className="text-white font-medium">Impact on Borrowing Capacity</h4>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Withdrawing</span>
                <span className="text-white">
                  {amount} {selectedToken}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Reduced Capacity</span>
                <span className="text-orange-400">-${impactOnBorrowing}</span>
              </div>
            </div>

            <Alert className="border-yellow-500 bg-yellow-500/10">
              <AlertTriangle className="h-4 w-4 text-yellow-500" />
              <AlertDescription className="text-yellow-200">
                Withdrawing collateral will reduce your borrowing capacity and may affect your health factor.
              </AlertDescription>
            </Alert>
          </div>
        )}

        <Button
          onClick={handleWithdraw}
          className="w-full bg-teal-600 hover:bg-teal-700"
          disabled={!selectedToken || !amount}
        >
          Withdraw Collateral
        </Button>
      </CardContent>
    </Card>
  )
}
