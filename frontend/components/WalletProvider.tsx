import { PropsWithChildren } from "react";
import { AptosWalletAdapterProvider, Network } from "@aptos-labs/wallet-adapter-react";
// Internal components
import { useToast } from "@/components/ui/use-toast";
// Internal constants

export function WalletProvider({ children }: PropsWithChildren) {
  const { toast } = useToast();

  return (
    <AptosWalletAdapterProvider
      autoConnect={true}
      dappConfig={{ network: "mainnet" as Network }}
      onError={(error) => {
        toast({
          variant: "destructive",
          title: "Error",
          description: error || "Unknown wallet error",
        });
      }}
    >
      {children}
    </AptosWalletAdapterProvider>
  );
}
