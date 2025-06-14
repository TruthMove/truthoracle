import {Aptos, AptosConfig} from "@aptos-labs/ts-sdk";
import {useWallet} from '@aptos-labs/wallet-adapter-react';
import {
    Button,
    Table,
    TableCaption,
    TableContainer,
    Tbody,
    Td,
    Th,
    Thead,
    Tr,
} from '@chakra-ui/react';
import {Network} from "aptos";
import {useEffect, useState, useCallback} from 'react';
import {getMarketMetadata, getUserMarketData} from "../../../blockend/aptosService";

function Activity() {
    function hexToAscii(hex:any) {
        let str = '';
        for (let i = 2; i < hex.length; i += 2) {
            str += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        }
        return str;
    }

    const {account, signAndSubmitTransaction} = useWallet()
    const [userMarketData, setUserMarketData] = useState<any>(null);

    const config = new AptosConfig({ network: Network.MAINNET });
    const aptos = new Aptos(config);
    const moduleAddress = "0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49";

    const fetchBets = useCallback(async () => {
        if (!account) return;

        const userData = await getUserMarketData(account?.address);
        console.log("User Data:", userData[0].length);

        const updatedUserMarketData:any[] = [];

        for (let i = 0; i < userData[0].length; i++) {
            console.log(i)
            const marketMetadata = await getMarketMetadata(i);
            console.log("Market Metadata:", marketMetadata[0]);

            if(userData[0][i]?.amount_invested!=0)
            updatedUserMarketData.push({ userData: userData[0][i], betData: marketMetadata[0] });
        }

        setUserMarketData(updatedUserMarketData);
    }, [account]);

    useEffect(() => {
        fetchBets();
    }, [fetchBets]);

    useEffect(() => {
        console.log("Updated User Market Data:", userMarketData);
    }, [userMarketData]);

    const handlePayout = async (data:any) => {
        if (!account) return;
            
        if(account){
            const committedTxn = await signAndSubmitTransaction({  data: {
                function: `${moduleAddress}::truthoracle::withdraw_payout`,
                typeArguments: [],
                functionArguments: [data?.id],
            }, });
            await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
            console.log(`Committed transaction: ${committedTxn.hash}`);
            // Refresh data after successful payout
            await fetchBets();
        }else{
            console.log("Account not available");
        }
    }

    // Expose the refresh function to the window object so it can be called from other components
    useEffect(() => {
        (window as any).refreshPortfolio = fetchBets;
        return () => {
            delete (window as any).refreshPortfolio;
        };
    }, [fetchBets]);

    return (
        <div className='font-jbm'> 
            <TableContainer color={"white"} mt={10}>
                <Table variant='simple'>
                    <TableCaption style={{ fontFamily: "'JetBrains Mono'" }}>Your Activity on TruthOracle</TableCaption>
                    <Thead>
                        <Tr>
                            <Th color={"white"} style={{ fontFamily: "'JetBrains Mono'" }}>Question</Th> 
                            <Th color={"white"} style={{ fontFamily: "'JetBrains Mono'" }}>Amount Invested</Th>
                            <Th color={"white"} style={{ fontFamily: "'JetBrains Mono'" }}>Prediction 1 - Shares Owned</Th>
                            <Th color={"white"} style={{ fontFamily: "'JetBrains Mono'" }}>Prediction 2 - Shares Owned</Th> 
                            <Th color={"white"} style={{ fontFamily: "'JetBrains Mono'" }}>Payout</Th> 
                        </Tr>
                    </Thead>
                    <Tbody>
                        {userMarketData?.map((data:any) => (
                            <Tr color={"#CCCCFF"} key={data.betData?.id}>
                                <Td className='font-jbm'>{hexToAscii(data?.betData?.question)}</Td> 
                                <Td className='font-jbm'>{"$"}{data?.userData?.amount_invested/10**8}</Td> 
                                <Td className='font-jbm'>{hexToAscii(data?.betData?.option_1)} - {data?.userData?.option_shares_1}</Td> 
                                <Td className='font-jbm'>{hexToAscii(data?.betData?.option_2)} - {data?.userData?.option_shares_2}</Td> 
                                <Td className='font-jbm'><Button onClick={()=>handlePayout(data?.betData)} bg={"#CCCCFF"} className=" text-black p-3 rounded-md">Withdraw</Button></Td>
                            </Tr>
                        ))}
                    </Tbody>
                </Table>
            </TableContainer>
        </div>
    );
}

export default Activity;
