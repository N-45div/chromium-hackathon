"use client"

import { Button } from "@/components/ui/button"
import { useWallet } from "@/hooks/use-wallet"
import { Wallet, ChevronDown } from "lucide-react"
import { cn } from "@/lib/utils"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"

interface ConnectWalletButtonProps {
  size?: "default" | "sm" | "lg"
  className?: string
}

export function ConnectWalletButton({ size = "default", className }: ConnectWalletButtonProps) {
  const { isConnected, address, connect, disconnect } = useWallet()

  if (isConnected && address) {
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="outline"
            size={size}
            className={cn("border-teal-500 text-teal-400 hover:bg-teal-500/10", className)}
          >
            <Wallet className="mr-2 w-4 h-4" />
            {`${address.slice(0, 6)}...${address.slice(-4)}`}
            <ChevronDown className="ml-2 w-4 h-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent className="bg-slate-800 border-slate-700">
          <DropdownMenuItem onClick={disconnect} className="text-white hover:bg-slate-700 cursor-pointer">
            Disconnect Wallet
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )
  }

  return (
    <Button
      onClick={connect}
      size={size}
      className={cn(
        "bg-gradient-to-r from-teal-500 to-cyan-500 hover:from-teal-600 hover:to-cyan-600 text-white font-semibold",
        className,
      )}
    >
      <Wallet className="mr-2 w-4 h-4" />
      Connect Wallet
    </Button>
  )
}
