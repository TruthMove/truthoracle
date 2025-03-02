import {Center, Stack, TabList, TabPanel, TabPanels, Tabs} from '@chakra-ui/react'
// import Summary from './Portfolio/Summary'
import Activity from './Portfolio/Activity'

type Props = {}

function Portfolio({}: Props) {
  return (
    <>
    <Stack minHeight={"100vh"} width={"100%"} px={10} color={"white"}>
        {/* <Heading textAlign={"center"} style={{ fontFamily: "'JetBrains Mono'" }}>My Portfolio</Heading>  */}

                <Tabs variant='unstyled'>
                  <TabList>
                    {/* <Tab _selected={{ color: 'black', bg: 'white' }} style={{ fontFamily: "'JetBrains Mono'" }} className='rounded-md'>Activity</Tab> */}
                    {/* <Tab  _selected={{ color: 'black', bg: 'white' }} style={{ fontFamily: "'JetBrains Mono'" }} className='rounded-md'>Summary</Tab> */}
                  </TabList>
                  <TabPanels>
                    <TabPanel>
                    <Center>
                      <Activity/>
                    </Center>  
                    </TabPanel>
                    {/* <TabPanel>
                      <Summary/>
                    </TabPanel> */}
                  </TabPanels>
                </Tabs>
    </Stack>   
    </>
  )
}

export default Portfolio