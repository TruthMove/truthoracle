import {useWallet} from "@aptos-labs/wallet-adapter-react";
import {Grid, Tabs, TabList, Tab, TabPanels, TabPanel, Box} from "@chakra-ui/react";
import {useEffect, useState} from "react";
import {getMarketCount, getMarketMetadata} from "../../blockend/aptosService";
import BetCard from "./BetCard";

const Marketplace = () => {
    const {account} = useWallet();
    const [activeBets, setActiveBets] = useState<any[]>([]);
    const [expiredBets, setExpiredBets] = useState<any[]>([]);

    useEffect(() => {
        const fetchBets = async () => {
            setActiveBets([]); // Clear previous bets
            setExpiredBets([]); // Clear previous expired bets

            try {
                const marketCount = await getMarketCount(); // Get the market count
                const newActiveBets: any[] = []; // Array to collect active bets
                const newExpiredBets: any[] = []; // Array to collect expired bets

                for (let i = 0; i < marketCount; i++) {
                    const marketMetadata: any = await getMarketMetadata(i); // Fetch market metadata
                    console.log("i", i);

                    if (marketMetadata.length > 0) {
                        if (marketMetadata[0].status === 0) { // Active market
                            if (i != 8 && i != 5) {
                                newActiveBets.push(marketMetadata[0]);
                            }
                        } else if (marketMetadata[0].status === 1) { // Expired market
                            newExpiredBets.push(marketMetadata[0]);
                        }
                    }
                }

                setActiveBets(newActiveBets); // Update state with active bets
                setExpiredBets(newExpiredBets); // Update state with expired bets
                console.log("Active Bets:", newActiveBets);
                console.log("Expired Bets:", newExpiredBets);
            } catch (error) {
                console.error("Error fetching bets:", error);
            }
        };

        fetchBets();
    }, [account]);

    return (
        <Box p={6} className="font-jbm">
            <Tabs variant="soft-rounded" colorScheme="blue" align="center" mb={6}>
                <TabList>
                    <Tab color="white">Active Markets</Tab>
                    <Tab color="white">Expired Markets</Tab>
                </TabList>
                <TabPanels>
                    <TabPanel>
                        <Grid
                            templateColumns={{
                                base: "repeat(2, 1fr)",
                                sm: "repeat(2, 1fr)",
                                md: "repeat(3, 1fr)",
                                lg: "repeat(3, 1fr)",
                            }}
                            gap={8}
                            alignItems={"center"}
                        >
                            {activeBets?.map((bet) => (
                                <div key={bet?.id} className="font-jbm">
                                    <BetCard {...bet} />
                                </div>
                            ))}
                        </Grid>
                    </TabPanel>
                    <TabPanel>
                        <Grid
                            templateColumns={{
                                base: "repeat(2, 1fr)",
                                sm: "repeat(2, 1fr)",
                                md: "repeat(3, 1fr)",
                                lg: "repeat(3, 1fr)",
                            }}
                            gap={8}
                            alignItems={"center"}
                        >
                            {expiredBets?.map((bet) => (
                                <div key={bet?.id} className="font-jbm">
                                    <BetCard {...bet} />
                                </div>
                            ))}
                        </Grid>
                    </TabPanel>
                </TabPanels>
            </Tabs>
        </Box>
    );
};

export default Marketplace;
