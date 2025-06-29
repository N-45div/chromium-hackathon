"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Badge } from "@/components/ui/badge"
import { Users, Plus, Trash2 } from "lucide-react"
import { useState } from "react"

const authorizedSigners = [
  { address: "0x742d35Cc6634C0532925a3b8D4C9db96590c6C87", label: "Primary Wallet" },
  { address: "0x8ba1f109551bD432803012645Hac136c22C501e", label: "Secondary Wallet" },
]

export function MultiSigSetup() {
  const [threshold, setThreshold] = useState("2")
  const [newSigner, setNewSigner] = useState("")

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white flex items-center">
          <Users className="w-5 h-5 mr-2 text-teal-400" />
          Multi-Signature Setup
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-2">
          <Label className="text-gray-300">Approval Threshold</Label>
          <Select value={threshold} onValueChange={setThreshold}>
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              <SelectItem value="1" className="text-white hover:bg-slate-600">
                1 of {authorizedSigners.length}
              </SelectItem>
              <SelectItem value="2" className="text-white hover:bg-slate-600">
                2 of {authorizedSigners.length}
              </SelectItem>
              <SelectItem value={authorizedSigners.length.toString()} className="text-white hover:bg-slate-600">
                {authorizedSigners.length} of {authorizedSigners.length}
              </SelectItem>
            </SelectContent>
          </Select>
          <p className="text-sm text-gray-400">Require {threshold} signature(s) for transactions above $10,000</p>
        </div>

        <div className="space-y-3">
          <Label className="text-gray-300">Authorized Signers</Label>
          <div className="space-y-2">
            {authorizedSigners.map((signer, index) => (
              <div key={index} className="flex items-center justify-between p-3 bg-slate-700/50 rounded-lg">
                <div>
                  <div className="text-white text-sm font-medium">{signer.label}</div>
                  <div className="text-gray-400 text-xs">{signer.address}</div>
                </div>
                <div className="flex items-center space-x-2">
                  <Badge variant="outline" className="border-green-500 text-green-400">
                    Active
                  </Badge>
                  <Button size="sm" variant="ghost" className="text-red-400 hover:text-red-300">
                    <Trash2 className="w-4 h-4" />
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-3">
          <Label className="text-gray-300">Add New Signer</Label>
          <div className="flex space-x-2">
            <Input
              placeholder="0x..."
              value={newSigner}
              onChange={(e) => setNewSigner(e.target.value)}
              className="bg-slate-700 border-slate-600 text-white flex-1"
            />
            <Button size="sm" className="bg-teal-600 hover:bg-teal-700">
              <Plus className="w-4 h-4 mr-1" />
              Add
            </Button>
          </div>
        </div>

        <div className="p-4 bg-slate-700/50 rounded-lg">
          <h4 className="text-white font-medium mb-2">Current Configuration</h4>
          <div className="space-y-1 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-400">Total Signers</span>
              <span className="text-white">{authorizedSigners.length}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Required Signatures</span>
              <span className="text-white">{threshold}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Threshold Amount</span>
              <span className="text-white">$10,000</span>
            </div>
          </div>
        </div>

        <Button className="w-full bg-teal-600 hover:bg-teal-700">Update Multi-Sig Configuration</Button>
      </CardContent>
    </Card>
  )
}
