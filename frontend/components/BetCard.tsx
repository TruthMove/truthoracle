import { Avatar, Flex, Stack } from '@chakra-ui/react';
import {useEffect, useState} from 'react';
import { useNavigate } from 'react-router-dom'; 

type Props = {
    id: string,
    createdAt: string,
    image_url:string;
    question: string;
    option_1: string;
    option_2: string;
};

const BetCard = (props: Props) => {
const navigate = useNavigate(); 
const [imageURL, setImageURL] = useState<any>("");

  const handleCardClick = () => {
    navigate(`/bet/${props.id}`);
  };

  useEffect(() => {
  setImageURL(hexToAscii(props.image_url));
  console.log(props);
}, [props]);


//   const handleBetClick = (value: string) => {
//     window.na
//   }

  function hexToAscii(hex:any) {
        let str = '';
        for (let i = 2; i < hex.length; i += 2) {
            str += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        }
        return str;
    }

  return (
    <Stack 
      width={"350px"} 
      height={"200px"} 
      bg={"#18191C"} 
      className="rounded-lg shadow-md p-4 font-jbm cursor-pointer" 
      key={props.id} 
      color={"white"}
      onClick={handleCardClick} 
    >
    //https://bit.ly/dan-abramov
      <Flex height={"80%"}>
        <Avatar mt={3}name='TruthOracle' src={imageURL} />
        <div style={{ fontWeight: "bold", marginTop: "10px", marginLeft: "10px", fontSize: "17px" }} className='font-jbm'>
          {hexToAscii(props.question)}
        </div>
      </Flex>

      {/* Yes/No Buttons */}
      <div className="px-4 pb-2 flex justify-between font-jbm">
        <button
          onClick={ handleCardClick} 
          style={{
            borderColor: "#008000",
            width: "50%",
            borderWidth: "2px",
            height: "auto", 
            padding: "10px 10px", 
            minWidth: "80px",
            maxWidth: "150px", 
            wordBreak: "break-word", 
            textAlign: "center",
            fontSize: "12px", 
          }}
          className="text-white font-bold hover:bg-green-600"
        >
          Bet {hexToAscii(props.option_1)}
        </button>
        <button
          onClick={handleCardClick} // Prevent click propagation to the card click
          style={{
            borderColor: "#FF0000",
                        width: "50%",

            borderWidth: "2px",
            height: "auto", 
            padding: "5px 10px", 
            minWidth: "80px",
            maxWidth: "150px", 
            wordBreak: "break-word", 
            textAlign: "center",
            fontSize: "12px", 
          }}
          className="text-white font-bold hover:bg-red-600"
        >
          Bet {hexToAscii(props.option_2)}
        </button>
      </div>

      {/* Card Footer */}
      
    </Stack>
  );
};

export default BetCard;
