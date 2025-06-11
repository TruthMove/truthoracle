import {
  APTOS_CONNECT_ACCOUNT_URL,
  AboutAptosConnect,
  AboutAptosConnectEducationScreen,
  AnyAptosWallet,
  AptosPrivacyPolicy,
  WalletItem,
  groupAndSortWallets,
  isAptosConnectWallet,
  isInstallRequired,
  truncateAddress,
  useWallet,
} from "@aptos-labs/wallet-adapter-react";
import { ArrowLeft, ArrowRight, ChevronDown, Copy, LogOut, ExternalLink } from "lucide-react";
import { useCallback, useState, useEffect } from "react";
// Internal components
import { Button } from "@/components/ui/button";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useToast } from "@/components/ui/use-toast";
import { getAccountAPTBalance } from "@/view-functions/getAccountBalance";
import { getPlatformUSDCBalance } from "../../blockend/aptosService";
import { useQuery } from "@tanstack/react-query";
import Pusher from 'pusher-js';

// Initialize Pusher with error handling
let pusher: Pusher | null = null;
try {
  const pusherKey = process.env.NEXT_PUBLIC_PUSHER_KEY || "5c9c8369bdc5cdcb8b7c";
  const pusherCluster = process.env.NEXT_PUBLIC_PUSHER_CLUSTER || "ap2";

  if (!pusherKey || !pusherCluster) {
    console.error('Pusher credentials not found in environment variables');
  } else {
    pusher = new Pusher(pusherKey, {
      cluster: pusherCluster,
      enabledTransports: ['ws', 'wss']
    });
  }
} catch (error) {
  console.error('Error initializing Pusher:', error);
}

interface AccountEvent {
  version: number;
  event_type: string;
  event_data: any;
  timestamp: number;
}

export function WalletSelector() {
  const { account, disconnect, connected, wallets } = useWallet();
  const { toast } = useToast();
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [wsStatus, setWsStatus] = useState<'connecting' | 'connected' | 'disconnected'>('disconnected');
  const [events, setEvents] = useState<any[]>([]);

  const { data: balanceData } = useQuery({
    queryKey: ["apt-balance", account?.address],
    refetchInterval: 10_000,
    queryFn: async () => {
      if (!account?.address) return { balance: 0 };
      try {
        const balance = await getAccountAPTBalance({ accountAddress: account.address });
        return { balance };
      } catch (error: any) {
        toast({
          variant: "destructive",
          title: "Error",
          description: error.message,
        });
        return { balance: 0 };
      }
    },
    enabled: !!account?.address,
  });

  const { data: usdcBalanceData } = useQuery({
    queryKey: ["usdc-balance", account?.address],
    refetchInterval: 10_000,
    queryFn: async () => {
      if (!account?.address) return { balance: 0 };
      try {
        const balance = await getPlatformUSDCBalance(account.address);
        return { balance };
      } catch (error: any) {
        toast({
          variant: "destructive",
          title: "Error",
          description: error.message,
        });
        return { balance: 0 };
      }
    },
    enabled: !!account?.address,
  });

  useEffect(() => {
    if (connected && account && pusher) {
      // Check initial connection state
      if (pusher.connection.state === 'connected') {
        setWsStatus('connected');
      } else {
        setWsStatus('connecting');
      }
      
      // Subscribe to the channel
      const channel = pusher.subscribe('account-events');

      // Listen for account events
      channel.bind('account-event', (data: any) => {
        console.log('Received event:', data);
        setEvents(prev => [data, ...prev].slice(0, 10)); // Keep last 10 events
      });

      // Handle connection state changes
      pusher.connection.bind('state_change', (states: any) => {
        console.log('Pusher connection state changed:', states);
        if (states.current === 'connected') {
          setWsStatus('connected');
        } else if (states.current === 'disconnected' || states.current === 'failed') {
          setWsStatus('disconnected');
        } else if (states.current === 'connecting') {
          setWsStatus('connecting');
        }
      });

      // Handle connection success
      pusher.connection.bind('connected', () => {
        console.log('Pusher connected');
        setWsStatus('connected');
      });

      // Handle errors
      pusher.connection.bind('error', (err: any) => {
        console.error('Pusher connection error:', err);
        setWsStatus('disconnected');
      });

      // Handle disconnection
      pusher.connection.bind('disconnected', () => {
        console.log('Disconnected from Pusher');
        setWsStatus('disconnected');
      });

      // Cleanup on unmount
      return () => {
        channel.unbind_all();
        channel.unsubscribe();
        setWsStatus('disconnected');
      };
    }
  }, [connected, account]);

  const formatEvent = (event: AccountEvent) => {
    const date = new Date(event.timestamp * 1000);
    const timeString = date.toLocaleTimeString();
    const moduleAddress = process.env.NEXT_PUBLIC_MODULE_ADDRESS || "0xf951a56dfc533b56fd092ae9aeeb2056a353d8a72c4ea76be674e84b9a61a3ec";
    
    switch (event.event_type) {
      case `${moduleAddress}::truthoracle::MarketCreated`:
        return `${timeString} - Created market: ${event.event_data.market_id}`;
      case `${moduleAddress}::truthoracle::buy_shares`:
        return `${timeString} - Bought shares: ${event.event_data.amount} for market ${event.event_data.market_id}`;
      case `${moduleAddress}::truthoracle::withdraw_payout`:
        return `${timeString} - Withdrew payout: ${event.event_data.amount} from market ${event.event_data.market_id}`;
      default:
        return `${timeString} - ${event.event_type}`;
    }
  };

  const closeDialog = useCallback(() => setIsDialogOpen(false), []);

  return connected ? (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button>{account?.ansName || truncateAddress(account?.address) || "Unknown"}</Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-80" style={{ zIndex: 1101 }}>
        <div className="px-4 py-2">
          <p className="text-sm font-medium">Balance</p>
          <p className="text-2xl font-bold">
            {balanceData?.balance ? (balanceData.balance / Math.pow(10, 8)).toFixed(4) : "0"} APT
          </p>
          <p className="text-sm font-medium mt-2">Platform USDC Balance</p>
          <p className="text-2xl font-bold">
            {usdcBalanceData?.balance ? (usdcBalanceData.balance / Math.pow(10, 8)).toFixed(2) : "0"} USD Coin
          </p>
        </div>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={disconnect}>
          Disconnect
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={() => {
          navigator.clipboard.writeText(account?.address || '');
          toast({
            title: "Address copied",
            description: "Your wallet address has been copied to clipboard",
          });
        }} className="flex gap-2">
          <Copy className="h-4 w-4" /> Copy address
        </DropdownMenuItem>
        {wallets?.find((wallet) => isAptosConnectWallet(wallet)) && (
          <DropdownMenuItem asChild>
            <a href={APTOS_CONNECT_ACCOUNT_URL} target="_blank" rel="noopener noreferrer" className="flex gap-2">
              <ExternalLink className="h-4 w-4" /> View on Explorer
            </a>
          </DropdownMenuItem>
        )}
        <DropdownMenuSeparator />
        <div className="px-4 py-2">
          <div className="flex items-center justify-between mb-2">
            <p className="text-sm font-medium">Recent Activity</p>
            <span className={`text-xs px-2 py-1 rounded ${
              wsStatus === 'connected' ? 'bg-green-100 text-green-800' :
              wsStatus === 'connecting' ? 'bg-yellow-100 text-yellow-800' :
              'bg-red-100 text-red-800'
            }`}>
              {wsStatus}
            </span>
          </div>
          <div className="max-h-32 overflow-y-auto">
            {events.length > 0 ? (
              events.map((event, index) => (
                <p key={index} className="text-sm text-muted-foreground py-1 border-b last:border-0">
                  {formatEvent(event.data)}
                </p>
              ))
            ) : (
              <p className="text-sm text-muted-foreground">No recent activity</p>
            )}
          </div>
        </div>
        <DropdownMenuSeparator />
        <DropdownMenuItem onSelect={disconnect} className="gap-2">
          <LogOut className="h-4 w-4" /> Disconnect
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  ) : (
    <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
      <DialogTrigger asChild>
        <Button className="font-jbm text-xl">Connect a Wallet</Button>
      </DialogTrigger>
      <ConnectWalletDialog close={closeDialog} />
    </Dialog>
  );
}

interface ConnectWalletDialogProps {
  close: () => void;
}

function ConnectWalletDialog({ close }: ConnectWalletDialogProps) {
  const { wallets = [] } = useWallet();
  const { aptosConnectWallets, availableWallets, installableWallets } = groupAndSortWallets(wallets);

  const hasAptosConnectWallets = !!aptosConnectWallets.length;

  return (
    <DialogContent className="max-h-screen overflow-auto">
      <AboutAptosConnect renderEducationScreen={renderEducationScreen}>
        <DialogHeader>
          <DialogTitle style={{zIndex:1}} className="flex flex-col text-center leading-snug">
            {hasAptosConnectWallets ? (
              <>
                <span>Log in or sign up</span>
                <span>with Social + Aptos Connect</span>
              </>
            ) : (
              "Connect Wallet"
            )}
          </DialogTitle>
        </DialogHeader>

        {hasAptosConnectWallets && (
          <div className="flex flex-col gap-2 pt-3">
            {aptosConnectWallets.map((wallet) => (
              <AptosConnectWalletRow key={wallet.name} wallet={wallet} onConnect={close} />
            ))}
            <p className="flex gap-1 justify-center items-center text-muted-foreground text-sm">
              Learn more about{" "}
              <AboutAptosConnect.Trigger className="flex gap-1 py-3 items-center text-foreground">
                Aptos Connect <ArrowRight size={16} />
              </AboutAptosConnect.Trigger>
            </p>
            <AptosPrivacyPolicy className="flex flex-col items-center py-1">
              <p className="text-xs leading-5">
                <AptosPrivacyPolicy.Disclaimer />{" "}
                <AptosPrivacyPolicy.Link className="text-muted-foreground underline underline-offset-4" />
                <span className="text-muted-foreground">.</span>
              </p>
              <AptosPrivacyPolicy.PoweredBy className="flex gap-1.5 items-center text-xs leading-5 text-muted-foreground" />
            </AptosPrivacyPolicy>
            <div className="flex items-center gap-3 pt-4 text-muted-foreground">
              <div className="h-px w-full bg-secondary" />
              Or
              <div className="h-px w-full bg-secondary" />
            </div>
          </div>
        )}

        <div className="flex flex-col gap-3 pt-3">
          {availableWallets.map((wallet) => (
            <WalletRow key={wallet.name} wallet={wallet} onConnect={close} />
          ))}
          {!!installableWallets.length && (
            <Collapsible className="flex flex-col gap-3">
              <CollapsibleTrigger asChild>
                <Button size="sm" variant="ghost" className="gap-2">
                  More wallets <ChevronDown />
                </Button>
              </CollapsibleTrigger>
              <CollapsibleContent className="flex flex-col gap-3">
                {installableWallets.map((wallet) => (
                  <WalletRow key={wallet.name} wallet={wallet} onConnect={close} />
                ))}
              </CollapsibleContent>
            </Collapsible>
          )}
        </div>
      </AboutAptosConnect>
    </DialogContent>
  );
}

interface WalletRowProps {
  wallet: AnyAptosWallet;
  onConnect?: () => void;
}

function WalletRow({ wallet, onConnect }: WalletRowProps) {
  return (
    <WalletItem
      wallet={wallet}
      onConnect={onConnect}
      className="flex items-center justify-between px-4 py-3 gap-4 border rounded-md"
    >
      <div className="flex items-center gap-4">
        <WalletItem.Icon className="h-6 w-6" />
        <WalletItem.Name className="text-base font-normal" />
      </div>
      {isInstallRequired(wallet) ? (
        <Button size="sm" variant="ghost" asChild>
          <WalletItem.InstallLink />
        </Button>
      ) : (
        <WalletItem.ConnectButton asChild>
          <Button size="sm">Connect</Button>
        </WalletItem.ConnectButton>
      )}
    </WalletItem>
  );
}

function AptosConnectWalletRow({ wallet, onConnect }: WalletRowProps) {
  return (
    <WalletItem wallet={wallet} onConnect={onConnect}>
      <WalletItem.ConnectButton asChild>
        <Button size="lg" variant="outline" className="w-full gap-4">
          <WalletItem.Icon className="h-5 w-5" />
          <WalletItem.Name className="text-base font-normal" />
        </Button>
      </WalletItem.ConnectButton>
    </WalletItem>
  );
}

function renderEducationScreen(screen: AboutAptosConnectEducationScreen) {
  return (
    <>
      <DialogHeader className="grid grid-cols-[1fr_4fr_1fr] items-center space-y-0">
        <Button variant="ghost" size="icon" onClick={screen.cancel}>
          <ArrowLeft />
        </Button>
        <DialogTitle className="leading-snug text-base text-center">About Aptos Connect</DialogTitle>
      </DialogHeader>

      <div className="flex h-[162px] pb-3 items-end justify-center">
        <screen.Graphic />
      </div>
      <div className="flex flex-col gap-2 text-center pb-4">
        <screen.Title className="text-xl" />
        <screen.Description className="text-sm text-muted-foreground [&>a]:underline [&>a]:underline-offset-4 [&>a]:text-foreground" />
      </div>

      <div className="grid grid-cols-3 items-center">
        <Button size="sm" variant="ghost" onClick={screen.back} className="justify-self-start">
          Back
        </Button>
        <div className="flex items-center gap-2 place-self-center">
          {screen.screenIndicators.map((ScreenIndicator, i) => (
            <ScreenIndicator key={i} className="py-4">
              <div className="h-0.5 w-6 transition-colors bg-muted [[data-active]>&]:bg-foreground" />
            </ScreenIndicator>
          ))}
        </div>
        <Button size="sm" variant="ghost" onClick={screen.next} className="gap-2 justify-self-end">
          {screen.screenIndex === screen.totalScreens - 1 ? "Finish" : "Next"}
          <ArrowRight size={16} />
        </Button>
      </div>
    </>
  );
}
