require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0xfa6ed66dce26773ccd148343ac888c15716c23ecf9c9d6a7ad9e7cc54718e354",
    },
  });
}
test();
