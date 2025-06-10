import {useWallet} from "@aptos-labs/wallet-adapter-react";
import { WalletSelector } from "./WalletSelector";
import { Link } from 'react-router-dom';
import {Button, useToast} from "@chakra-ui/react";
// import {aptos} from '../utils/aptosClient';
// import {useEffect} from "react";
import {  Network } from "aptos";
import { Aptos, AptosConfig } from "@aptos-labs/ts-sdk";

export function Header() {

    const { account, signAndSubmitTransaction } = useWallet();

    const config = new AptosConfig({ network: Network.MAINNET });
    const aptos = new Aptos(config);

   const toast = useToast()


        const handleClick = async (e:any) => {
        e.preventDefault();

         if (!account) {
            console.error("Account not available");
            return;
        }

        const moduleAddress = "0x7fee3c77c04a65b0e05ba00cfa5d577f6dabffc763caeb84b021f96fa564bd9d"

        if(account){
                const committedTxn = await signAndSubmitTransaction({  data: {
                 function: `${moduleAddress}::usdc::mint`,
                 typeArguments: [],
                 functionArguments: [account?.address, 10**10]
            }, });
                await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
                console.log(`Committed transaction: ${committedTxn.hash}`);
                // window.alert("Minted USDC successfully!");
                  toast({
          title: 'USDC Minted',
          description: "We've added USDC to your account",
          status: 'success',
          duration: 9000,
          isClosable: true,
        })
        }else{
            console.log("Account not available");
        }

        
    }




  return (
    <div
      className="header-sticky"
      style={{
        backgroundColor: "#1C2526",
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: '10px',
        color: "white",
        borderBottom: '1px solid gray',
        position: 'fixed',
        top: 0,
        left: 0,
        height: '64px',
        width: '100%',
        zIndex: 1000
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <img src="/logonobg.svg" alt="Logo" width={40} height={40} style={{ marginRight: '10px' }} />
        <Link to="/" style={{ zIndex: 1 }}>
          <h1 className="font-jbm text-xl">TruthOracle</h1>
        </Link>
      </div>
      <div style={{ display: 'flex', justifyContent:"flex-end", width:"70%"}}>
        <Link to="/marketplace" className="font-jbm text-l" style={{marginRight:"40px", zIndex:1}}>Marketplace</Link>
        <Link to={`/portfolio/${account?.address}`}  style={{marginRight:"40px", zIndex:1}} className="font-jbm text-l">Portfolio</Link>
        <Link to="/rewards" className="font-jbm text-l" style={{marginRight:"40px", zIndex:1}}>Rewards</Link>
        <Link to="/faq" className="font-jbm text-l" style={{marginRight:"40px", zIndex:1}}>FAQ's</Link>
        <Link to="/admin" className="font-jbm text-l" style={{marginRight:"40px", zIndex:1}}>Create Market</Link>
                <Button onClick={handleClick} style={{zIndex:1, borderRadius:"20px", "height":"30px"}}>Mint USDC</Button>


      </div>
      <div className="ml-auto">
        <WalletSelector />
      </div>
    </div>
  );
}

