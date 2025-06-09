require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0x9ad719eeeaba8bca2c6e489caaee2723c8f071ff0ed31d31f41ea93adb5b1ceb",
    },
  });
}
test();
