require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0x7fee3c77c04a65b0e05ba00cfa5d577f6dabffc763caeb84b021f96fa564bd9d",
    },
  });
}
test();
