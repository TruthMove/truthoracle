require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49",
    },
  });
}
test();
