import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Box, Button, Heading, Text, VStack, useToast } from "@chakra-ui/react";
import { useEffect, useState } from "react";
import { getUserRewards, claimAllRewards, getClaimedMarkets } from "../../blockend/aptosService";

const Rewards = () => {
    const { account } = useWallet();
    const [rewards, setRewards] = useState<{ pending: number; total: number }>({ pending: 0, total: 0 });
    const [claimedMarkets, setClaimedMarkets] = useState<number[]>([]);
    const [loading, setLoading] = useState(false);
    const [initialLoading, setInitialLoading] = useState(true);
    const toast = useToast();

    const fetchRewardsAndClaims = async () => {
        if (account?.address) {
            setInitialLoading(true);
            try {
                const [pending, total] = await getUserRewards(account.address);
                setRewards({
                    pending: Number(pending) / 1e8, // Convert from base units to USDC
                    total: Number(total) / 1e8
                });
                const claimed = await getClaimedMarkets(account.address);
                setClaimedMarkets(claimed.map((id: any) => Number(id)));
            } catch (error) {
                console.error("Error fetching rewards or claimed markets:", error);
            }
            setInitialLoading(false);
        } else {
            setInitialLoading(false);
        }
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
            await claimAllRewards(account);
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
                description: "Failed to claim all rewards",
                status: "error",
                duration: 3000,
                isClosable: true,
            });
        }
        setLoading(false);
    };

    return (
        <div style={{ maxHeight: "100vh", paddingTop: "60px" }} className="font-jbm">
            {initialLoading ? (
                <Box maxW="600px" mx="auto" w="100%" p={6} textAlign="center">
                    <Text color="white" fontSize="xl">Loading...</Text>
                </Box>
            ) : (
                <Box maxW="600px" mx="auto" w="100%" p={6}>
                    <VStack spacing={3} align="stretch">
                        <Heading size="lg" color="white">Your Rewards</Heading>

                        {/* Already Claimed Rewards Section */}
                        <Box p={2} borderWidth={1} borderRadius="lg" bg="#23292B" mb={2}>
                            <Heading size="md" color="white" mb={2}>Already Claimed Rewards</Heading>
                            {claimedMarkets.length === 0 ? (
                                <Text color="#E0E0E0">No rewards have been claimed yet.</Text>
                            ) : (
                                <Text color="#E0E0E0">Claimed Market IDs: {claimedMarkets.join(", ")}</Text>
                            )}
                        </Box>

                        {/* Rewards Available to be Claimed Section */}
                        <Box p={2} borderWidth={1} borderRadius="lg" bg="#23292B">
                            <Heading size="md" color="white" mb={2}>Rewards Available to be Claimed</Heading>
                            <Text fontSize="xl" fontWeight="bold" color="white">
                                Pending Rewards: {rewards.pending.toFixed(2)} USDC
                            </Text>
                            <Text fontSize="md" color="#E0E0E0" mt={2}>
                                Total Earned: {rewards.total.toFixed(2)} USDC
                            </Text>
                        </Box>

                        <Button
                            colorScheme="blue"
                            onClick={handleClaimAllRewards}
                            isDisabled={rewards.pending === 0 || loading}
                            isLoading={loading}
                        >
                            Claim All Rewards
                        </Button>

                        <Box mt={4}>
                            <Heading size="md" mb={4} color="white">How to Earn Rewards</Heading>
                            <VStack align="stretch" spacing={3}>
                                <Text color="#E0E0E0">• Early Participant Bonus: 0.05 USDC for early market participation</Text>
                                <Text color="#E0E0E0">• Market Creator Reward: 0.1 USDC for creating a new market</Text>
                                <Text color="#E0E0E0">• Winning Prediction Bonus: 0.2 USDC for correct predictions</Text>
                            </VStack>
                        </Box>
                    </VStack>
                </Box>
            )}
        </div>
    );
};

export default Rewards; 