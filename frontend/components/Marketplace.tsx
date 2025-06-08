import {useWallet} from "@aptos-labs/wallet-adapter-react";
import {Grid} from "@chakra-ui/react";
import {useEffect, useState} from "react";
import {getMarketCount, getMarketMetadata} from "../../blockend/aptosService";
import BetCard from "./BetCard";




const Marketplace = () => {

    const {account} = useWallet();
    const [bets, setBets] = useState<any[]>([]);

    


useEffect(() => {
    const fetchBets = async () => {
        setBets([]); // Clear previous bets

        try {
            const marketCount = await getMarketCount(); // Get the market count
            const newBets:any[] = []; // Array to collect new bets

            for (let i = 0; i < marketCount; i++) {
                
                const marketMetadata:any = await getMarketMetadata(i); // Fetch market metadata
                console.log("i", i);


                if (marketMetadata.length>0 && marketMetadata?.[0]?.status === 0) {
                    if(i!=8 && i!=5)
                    newBets.push(marketMetadata[0]); // Add valid bets to the array
                }
            }

            setBets(newBets); // Update state once all data is collected
            console.log("Bets:", newBets);
        } catch (error) {
            console.error("Error fetching bets:", error);
        }
    };

    fetchBets();
}, [account]);


//   useEffect(() => {

//     const buyShares = async () => {
        
//          if (!account) {
//             console.error("Account not available");
//             return;
//         }

//         await aptos.transaction.build.simple({
//             sender: account.address ?? "",
//             data: {
//               function: `${moduleAddress}::truthoracle::buy_shares`,
//               typeArguments: [],
//               functionArguments: [

//                 new U64(0),
//                 new U64(0),
//                 new U64(10),
//                ],
//             },
//         });

        
//         if(account){
//                 const committedTxn = await signAndSubmitTransaction({  data: {
//                  function: `${moduleAddress}::truthoracle::buy_shares`,
//                  typeArguments: [],
//                  functionArguments:[ 0,0,10],
//             }, });
//                 await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
//                 console.log(`Committed transaction: ${committedTxn.hash}`);
//         }else{
//             console.log("Account not available");
//         }

//     }

//     buyShares();
//   }, [account]);



    


  return (
    <>
    {!bets && <div>"Loading..."</div>}
    {bets && <div style={{ maxHeight: "100vh" }} className="font-jbm">
      <Grid
        mt={5}
        templateColumns={{
          base: "repeat(2, 1fr)",
          sm: "repeat(2, 1fr)",
          md: "repeat(3, 1fr)",
          lg: "repeat(3, 1fr)",
        }}
        gap={8}
        alignItems={"center"}
        p={6}
      >
        {bets?.map((bet) => (
            <div className="font-jbm">
                <BetCard key={bet?.id} {...bet} />
            </div>
        
        ))}
      </Grid>
    </div>}
    </>
  );
};

export default Marketplace;
