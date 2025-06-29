"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Switch } from "@/components/ui/switch"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Lock, Eye, EyeOff } from "lucide-react"
import { useState } from "react"

export function PrivacyControls() {
  const [crossChainPrivacy, setCrossChainPrivacy] = useState(true)
  const [transactionConfidentiality, setTransactionConfidentiality] = useState(false)
  const [anonymousBorrowing, setAnonymousBorrowing] = useState(false)
  const [zkProofs, setZkProofs] = useState("optional")

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white flex items-center">
          <Lock className="w-5 h-5 mr-2 text-teal-400" />
          Privacy Controls
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-4">
          <h4 className="text-white font-medium">Cross-Chain Privacy</h4>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="space-y-1">
                <Label htmlFor="cross-chain-privacy" className="text-sm text-white">
                  Enable Cross-Chain Privacy
                </Label>
                <p className="text-xs text-gray-400">Hide transaction details when bridging between chains</p>
              </div>
              <Switch id="cross-chain-privacy" checked={crossChainPrivacy} onCheckedChange={setCrossChainPrivacy} />
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <h4 className="text-white font-medium">Transaction Confidentiality</h4>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="space-y-1">
                <Label htmlFor="transaction-confidentiality" className="text-sm text-white">
                  Private Transaction Amounts
                </Label>
                <p className="text-xs text-gray-400">Hide transaction amounts from public view</p>
              </div>
              <Switch
                id="transaction-confidentiality"
                checked={transactionConfidentiality}
                onCheckedChange={setTransactionConfidentiality}
              />
            </div>

            <div className="flex items-center justify-between">
              <div className="space-y-1">
                <Label htmlFor="anonymous-borrowing" className="text-sm text-white">
                  Anonymous Borrowing
                </Label>
                <p className="text-xs text-gray-400">Use privacy pools for borrowing transactions</p>
              </div>
              <Switch id="anonymous-borrowing" checked={anonymousBorrowing} onCheckedChange={setAnonymousBorrowing} />
            </div>
          </div>
        </div>

        <div className="space-y-3">
          <Label className="text-gray-300">Zero-Knowledge Proof Options</Label>
          <Select value={zkProofs} onValueChange={setZkProofs}>
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              <SelectItem value="disabled" className="text-white hover:bg-slate-600">
                Disabled
              </SelectItem>
              <SelectItem value="optional" className="text-white hover:bg-slate-600">
                Optional (Recommended)
              </SelectItem>
              <SelectItem value="required" className="text-white hover:bg-slate-600">
                Always Required
              </SelectItem>
            </SelectContent>
          </Select>
          <p className="text-sm text-gray-400">Zero-knowledge proofs provide mathematical privacy guarantees</p>
        </div>

        <div className="p-4 bg-slate-700/50 rounded-lg">
          <h4 className="text-white font-medium mb-3">Privacy Status</h4>
          <div className="space-y-2">
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-400">Cross-Chain Privacy</span>
              <div className="flex items-center space-x-1">
                {crossChainPrivacy ? (
                  <>
                    <EyeOff className="w-4 h-4 text-green-400" />
                    <span className="text-green-400">Enabled</span>
                  </>
                ) : (
                  <>
                    <Eye className="w-4 h-4 text-gray-400" />
                    <span className="text-gray-400">Disabled</span>
                  </>
                )}
              </div>
            </div>
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-400">Transaction Privacy</span>
              <div className="flex items-center space-x-1">
                {transactionConfidentiality ? (
                  <>
                    <EyeOff className="w-4 h-4 text-green-400" />
                    <span className="text-green-400">Private</span>
                  </>
                ) : (
                  <>
                    <Eye className="w-4 h-4 text-gray-400" />
                    <span className="text-gray-400">Public</span>
                  </>
                )}
              </div>
            </div>
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-400">ZK Proofs</span>
              <span className="text-white capitalize">{zkProofs}</span>
            </div>
          </div>
        </div>

        <div className="p-3 bg-blue-500/10 border border-blue-500/30 rounded-lg">
          <p className="text-sm text-blue-300">
            <strong>Note:</strong> Enhanced privacy features may increase transaction costs and processing time.
          </p>
        </div>

        <Button className="w-full bg-teal-600 hover:bg-teal-700">Save Privacy Settings</Button>
      </CardContent>
    </Card>
  )
}
