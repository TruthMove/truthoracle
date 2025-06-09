require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0x8a34ab45bd5101283b4f51d32ca7aaca9b1ce0ac0ed0a2ad58bcd114ca665b71",
    },
  });
}
test();
