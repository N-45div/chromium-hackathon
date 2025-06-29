"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Badge } from "@/components/ui/badge"
import { Bell, Webhook, Mail, MessageSquare } from "lucide-react"
import { useState } from "react"

const alertTypes = [
  { id: "liquidation", label: "Liquidation Warnings", enabled: true, threshold: "1.5" },
  { id: "market", label: "Market Opportunities", enabled: false, threshold: "2.0" },
  { id: "security", label: "Security Alerts", enabled: true, threshold: "immediate" },
  { id: "maintenance", label: "System Maintenance", enabled: true, threshold: "24h" },
]

export function MonitoringAlerts() {
  const [webhookUrl, setWebhookUrl] = useState("")
  const [emailNotifications, setEmailNotifications] = useState(true)
  const [slackIntegration, setSlackIntegration] = useState(false)

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white flex items-center">
          <Bell className="w-5 h-5 mr-2 text-teal-400" />
          Monitoring & Alerts
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-4">
          <h4 className="text-white font-medium">Alert Configuration</h4>
          <div className="space-y-3">
            {alertTypes.map((alert) => (
              <div key={alert.id} className="flex items-center justify-between p-3 bg-slate-700/50 rounded-lg">
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-1">
                    <Label className="text-sm text-white">{alert.label}</Label>
                    <Badge
                      variant="outline"
                      className={alert.enabled ? "border-green-500 text-green-400" : "border-gray-500 text-gray-400"}
                    >
                      {alert.enabled ? "Active" : "Inactive"}
                    </Badge>
                  </div>
                  <p className="text-xs text-gray-400">Threshold: {alert.threshold}</p>
                </div>
                <Switch checked={alert.enabled} onCheckedChange={() => {}} />
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-4">
          <h4 className="text-white font-medium">Notification Channels</h4>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <Mail className="w-4 h-4 text-blue-400" />
                <Label className="text-sm text-white">Email Notifications</Label>
              </div>
              <Switch checked={emailNotifications} onCheckedChange={setEmailNotifications} />
            </div>

            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <MessageSquare className="w-4 h-4 text-green-400" />
                <Label className="text-sm text-white">Slack Integration</Label>
              </div>
              <Switch checked={slackIntegration} onCheckedChange={setSlackIntegration} />
            </div>
          </div>
        </div>

        <div className="space-y-3">
          <div className="flex items-center space-x-2">
            <Webhook className="w-4 h-4 text-purple-400" />
            <Label className="text-gray-300">Webhook Configuration</Label>
          </div>
          <Input
            placeholder="https://your-webhook-url.com/alerts"
            value={webhookUrl}
            onChange={(e) => setWebhookUrl(e.target.value)}
            className="bg-slate-700 border-slate-600 text-white"
          />
          <p className="text-sm text-gray-400">Receive real-time alerts via webhook for institutional integrations</p>
        </div>

        <div className="space-y-3">
          <Label className="text-gray-300">Alert Frequency</Label>
          <Select defaultValue="immediate">
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              <SelectItem value="immediate" className="text-white hover:bg-slate-600">
                Immediate
              </SelectItem>
              <SelectItem value="hourly" className="text-white hover:bg-slate-600">
                Hourly Digest
              </SelectItem>
              <SelectItem value="daily" className="text-white hover:bg-slate-600">
                Daily Summary
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="p-4 bg-slate-700/50 rounded-lg">
          <h4 className="text-white font-medium mb-3">Recent Alerts</h4>
          <div className="space-y-2">
            <div className="flex items-center justify-between text-sm">
              <div className="flex items-center space-x-2">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span className="text-white">Health factor improved to 2.45</span>
              </div>
              <span className="text-gray-400">2 min ago</span>
            </div>
            <div className="flex items-center justify-between text-sm">
              <div className="flex items-center space-x-2">
                <div className="w-2 h-2 bg-blue-400 rounded-full"></div>
                <span className="text-white">New lending opportunity on Avalanche</span>
              </div>
              <span className="text-gray-400">1 hour ago</span>
            </div>
            <div className="flex items-center justify-between text-sm">
              <div className="flex items-center space-x-2">
                <div className="w-2 h-2 bg-yellow-400 rounded-full"></div>
                <span className="text-white">ETH price volatility increased</span>
              </div>
              <span className="text-gray-400">3 hours ago</span>
            </div>
          </div>
        </div>

        <Button className="w-full bg-teal-600 hover:bg-teal-700">Save Alert Settings</Button>
      </CardContent>
    </Card>
  )
}
