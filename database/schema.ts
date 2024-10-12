import { appSchema, tableSchema } from "@nozbe/watermelondb";
import "reflect-metadata";
import { injectable } from "inversify";

export default appSchema({
  version: 1,
  tables: [],
});
