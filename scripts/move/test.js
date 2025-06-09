require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0x8aa68add43456010ea13743fb7fa51fe1983f8f5746340f8ca1ea9accd1472ab",
    },
  });
}
test();
