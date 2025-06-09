import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Box, Button, Heading, Text, VStack, useToast, HStack, Spinner, IconButton } from "@chakra-ui/react";
import { useEffect, useState } from "react";
import { getUserRewards, getClaimedMarkets } from "../../blockend/aptosService";
import { RepeatIcon } from "@chakra-ui/icons";
import { Aptos, AptosConfig } from "@aptos-labs/ts-sdk";
import { Network } from "aptos";

const moduleAddress = "0x2a6c6b97583161fa7f130c062dd2216b882e35546a4b648f0e9769745397405e";
const config = new AptosConfig({ network: Network.MAINNET });
const aptos = new Aptos(config);

const Rewards = () => {
    const { account, signAndSubmitTransaction } = useWallet();
    const [rewards, setRewards] = useState<{ pending: number; total: number }>({ pending: 0, total: 0 });
    const [claimedMarkets, setClaimedMarkets] = useState<number[]>([]);
    const [loading, setLoading] = useState(false);
    const [refreshing, setRefreshing] = useState(false);
    const [initialLoading, setInitialLoading] = useState(true);
    const toast = useToast();

    const fetchRewardsAndClaims = async () => {
        if (account?.address) {
            try {
                const [pending, total] = await getUserRewards(account.address);
                console.log({
                    pending,
                    total
                });
                setRewards({
                    pending: Number(pending) / 1e8, // Convert from base units to USDC
                    total: Number(total) / 1e8
                });
                const claimed = await getClaimedMarkets(account.address);
                setClaimedMarkets(claimed.map((id: any) => Number(id)));
            } catch (error) {
                console.error("Error fetching rewards or claimed markets:", error);
                toast({
                    title: "Error",
                    description: "Failed to fetch rewards data. Please try again.",
                    status: "error",
                    duration: 3000,
                    isClosable: true,
                });
            }
        }
        setInitialLoading(false);
        setRefreshing(false);
    };

    useEffect(() => {
        fetchRewardsAndClaims();
        // eslint-disable-next-line
    }, [account]);

    const handleClaimAllRewards = async () => {
        if (!account) {
            toast({
                title: "Error",
                description: "Please connect your wallet first",
                status: "error",
                duration: 3000,
                isClosable: true,
            });
            return;
        }
        setLoading(true);
        try {
            const committedTxn = await signAndSubmitTransaction({
                data: {
                    function: `${moduleAddress}::incentives::claim_all_rewards`,
                    typeArguments: [],
                    functionArguments: [],
                },
            });
            await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
            
            toast({
                title: "Success",
                description: "All available rewards claimed successfully!",
                status: "success",
                duration: 3000,
                isClosable: true,
            });
            await fetchRewardsAndClaims();
        } catch (error) {
            console.error("Error claiming all rewards:", error);
            toast({
                title: "Error",
                description: "Failed to claim rewards. Please try again.",
                status: "error",
                duration: 3000,
                isClosable: true,
            });
        }
        setLoading(false);
    };

    const handleRefresh = async () => {
        setRefreshing(true);
        await fetchRewardsAndClaims();
    };

    if (initialLoading) {
        return (
            <Box maxW="600px" mx="auto" w="100%" p={6} textAlign="center">
                <Spinner size="xl" color="blue.500" />
                <Text color="white" fontSize="xl" mt={4}>Loading rewards data...</Text>
            </Box>
        );
    }

    return (
        <div style={{ maxHeight: "100vh", paddingTop: "60px" }} className="font-jbm">
            <Box maxW="600px" mx="auto" w="100%" p={6}>
                <VStack spacing={4} align="stretch">
                    <HStack justify="space-between" align="center">
                        <Heading size="lg" color="white">Your Rewards</Heading>
                        <IconButton
                            aria-label="Refresh rewards"
                            icon={<RepeatIcon />}
                            onClick={handleRefresh}
                            isLoading={refreshing}
                            colorScheme="blue"
                            variant="ghost"
                        />
                    </HStack>

                    {/* Rewards Available to be Claimed Section */}
                    <Box p={4} borderWidth={1} borderRadius="lg" bg="#23292B">
                        <Heading size="md" color="white" mb={3}>Available Rewards</Heading>
                        <VStack align="stretch" spacing={2}>
                            <HStack justify="space-between">
                                <Text color="#E0E0E0">Pending Rewards:</Text>
                                <Text fontSize="xl" fontWeight="bold" color="white">
                                    {rewards.pending.toFixed(2)} USDC
                                </Text>
                            </HStack>
                            <HStack justify="space-between">
                                <Text color="#E0E0E0">Total Earned:</Text>
                                <Text fontSize="lg" color="white">
                                    {rewards.total.toFixed(2)} USDC
                                </Text>
                            </HStack>
                        </VStack>
                    </Box>

                    <Button
                        colorScheme="blue"
                        onClick={handleClaimAllRewards}
                        isDisabled={rewards.pending === 0 || loading}
                        isLoading={loading}
                        size="lg"
                    >
                        {rewards.pending === 0 ? "No Rewards to Claim" : "Claim All Rewards"}
                    </Button>

                    {/* Already Claimed Rewards Section */}
                    <Box p={4} borderWidth={1} borderRadius="lg" bg="#23292B">
                        <Heading size="md" color="white" mb={3}>Claimed Rewards</Heading>
                        {claimedMarkets.length === 0 ? (
                            <Text color="#E0E0E0">No rewards have been claimed yet.</Text>
                        ) : (
                            <VStack align="stretch" spacing={2}>
                                <Text color="#E0E0E0">You have claimed rewards from {claimedMarkets.length} markets:</Text>
                                <Box 
                                    p={2} 
                                    bg="#1A1F21" 
                                    borderRadius="md" 
                                    maxH="150px" 
                                    overflowY="auto"
                                >
                                    <Text color="#E0E0E0" fontSize="sm">
                                        Market IDs: {claimedMarkets.join(", ")}
                                    </Text>
                                </Box>
                            </VStack>
                        )}
                    </Box>

                    {/* How to Earn Section */}
                    <Box p={4} borderWidth={1} borderRadius="lg" bg="#23292B">
                        <Heading size="md" mb={3} color="white">How to Earn Rewards</Heading>
                        <VStack align="stretch" spacing={3}>
                            <Box p={2} bg="#1A1F21" borderRadius="md">
                                <Text color="#E0E0E0" fontWeight="bold">Early Participant Bonus</Text>
                                <Text color="#E0E0E0" fontSize="sm">Earn 0.05 USDC for early market participation (≥ 1 USDC investment)</Text>
                            </Box>
                            <Box p={2} bg="#1A1F21" borderRadius="md">
                                <Text color="#E0E0E0" fontWeight="bold">Market Creator Reward</Text>
                                <Text color="#E0E0E0" fontSize="sm">Earn 0.1 USDC for creating a new market</Text>
                            </Box>
                            <Box p={2} bg="#1A1F21" borderRadius="md">
                                <Text color="#E0E0E0" fontWeight="bold">Winning Prediction Bonus</Text>
                                <Text color="#E0E0E0" fontSize="sm">Earn 0.2 USDC for correct predictions</Text>
                            </Box>
                        </VStack>
                    </Box>
                </VStack>
            </Box>
        </div>
    );
};

export default Rewards; 