require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0x3696815e695bf27c6bbf129630ebda6b49fb482aecb2b57e4cfd039aa2921281",
    },
  });
}
test();
