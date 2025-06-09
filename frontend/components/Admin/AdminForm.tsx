import {Button, Center, Input, useToast} from '@chakra-ui/react'
import React, {useState} from 'react'
// @ts-ignore
import { initMarket , getMarketCount, getMarketMetadata} from "../../../blockend/aptosService"; 

import {  Network } from "aptos";
import { Account, Aptos, AptosConfig } from "@aptos-labs/ts-sdk";
import {
  useWallet,
} from "@aptos-labs/wallet-adapter-react";
type Props = {}


function AdminForm({}: Props) {

    const acc = Account.generate();
    const { account, signAndSubmitTransaction } = useWallet();

    const config = new AptosConfig({ network: Network.MAINNET });
    const aptos = new Aptos(config);


    const [formData, setFormData] = useState({
		question: "",
        imageURL:"",
        description:"",
        firstShareOption:"",
        secondShareOption:"",
        liquidityParameter:100
	})


    const handleInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
		const { name, value } = event.target
		setFormData((prevFormData) => ({
			...prevFormData,
			[name]: value,
		}))

        console.log("acc: " , acc);
	}

    const moduleAddress = "0x3696815e695bf27c6bbf129630ebda6b49fb482aecb2b57e4cfd039aa2921281";

    const toast = useToast()



    const handleSubmit = async (e:any) => {
        e.preventDefault();

         if (!account) {
            console.error("Account not available");
            return;
        }

        //  await aptos.transaction.build.simple({
        //     sender: account.address ?? "",
        //     data: {
        //       function: `${moduleAddress}::truthoracle::init_market`,
        //       typeArguments: [],
        //       functionArguments: [

        //         formData.question,
        //         formData.imageURL,
        //         formData.description, 
        //         formData.firstShareOption, 
        //         formData.secondShareOption, 
        //         new U64(formData.liquidityParameter)
        //        ],
        //     },
        // });


        // const value = await client.getAccountResources(moduleAddress);
        // console.log(value);

  
        if(account){
                const committedTxn = await signAndSubmitTransaction({  data: {
                 function: `${moduleAddress}::truthoracle::init_market`,
                 typeArguments: [],
                 functionArguments: [formData.question, formData.imageURL, formData.description, formData.firstShareOption, formData.secondShareOption, formData.liquidityParameter],
            }, });
                await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
                console.log(`Committed transaction: ${committedTxn.hash}`);
                  toast({
                      title: 'Market Created',
                      description: "We've created market successfully!",
                      status: 'success',
                      duration: 9000,
                      isClosable: true,
                    })
        }else{
            console.log("Account not available");
        }

        
    }

//     const addNewList = async () => {
//   if (!account) return [];

//   const transaction:InputTransactionData = {
//       data: {
//         function:`${moduleAddress}::initMarket::truthoracle`,
//         functionArguments:[]
//       }
//     }
//   try {
//     // sign and submit transaction to chain
//     const response = await signAndSubmitTransaction(transaction);
//     // wait for transaction
//     await aptos.waitForTransaction({transactionHash:response.hash});
//   } catch (error: any) {
//   } finally {
//   }
// };
  return (
    <>
    <Center className="font-jbm" width={"50%"} bgColor={"white"} padding={"20px"} borderRadius={"10px"} boxShadow={"2xl"}>
    <form onSubmit={handleSubmit}>
									
        <label htmlFor="question">Question</label>
		<Input
			required
			type="text"
			marginBottom="20px"
			marginTop="2px"
			name="question"
			placeholder="Prediction Question"
			value={formData.question}
			onChange={handleInputChange}
		/>

        <label htmlFor="imageURL">Image URL</label>
		<Input
			required
			type="text"
			marginBottom="20px"
			marginTop="2px"
			name="imageURL"
			placeholder="Add Image URL"
			value={formData.imageURL}
			onChange={handleInputChange}
		/>

        <label htmlFor="description">Description</label>
		<Input
			required
			type="text"
			marginBottom="20px"
			marginTop="2px"
			name="description"
			placeholder="Add Description"
			value={formData.description}
			onChange={handleInputChange}
		/>

		<label htmlFor="firstShareOption">Prediction Option - 1</label>
		<Input
			type="text"
			marginBottom="25px"
			marginTop="2px"
			placeholder="Prediction Option"
			name="firstShareOption"
			value={formData.firstShareOption}
			onChange={handleInputChange}
			required={true}
		/>

   
        <label htmlFor="secondShareOption">Prediction Option - 2</label>
		<Input
			type="text"
			marginBottom="20px"
			marginTop="2px"
			placeholder="Prediction Option"
			name="secondShareOption"
			value={formData.secondShareOption}
			onChange={handleInputChange}
			required
		/>

    

        {/* <label htmlFor="liquidityParameter">Liquidity Parameter</label>
		<Input
			type="number"
			marginBottom="20px"
			marginTop="2px"
			placeholder="Liquidity Parameter"
			name="liquidityParameter"
			value={formData.liquidityParameter}
			onChange={handleInputChange}
		/> */}
		    <Button type="submit" colorScheme='green'>Submit</Button>

			
        </form>
    </Center>

    </>
  )
}

export default AdminForm