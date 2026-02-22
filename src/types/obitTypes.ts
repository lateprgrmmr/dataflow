import * as t from "io-ts";
import { DateFromISOString } from "io-ts-types/lib/DateFromISOString";
import { PathReporter } from "io-ts/lib/PathReporter";

const FuneralHomeType = t.type({
  id: t.union([t.string, t.null]),
  name: t.union([t.string, t.null]),
});

export interface FuneralHome extends t.TypeOf<typeof FuneralHomeType> {}

export class FuneralHome {
  public static validate(body: FuneralHome) {
    let errObj = {};
    const validationResult = t
      .exact(FuneralHomeType)
      .decode(JSON.parse(JSON.stringify(body)));
    if (validationResult._tag === "Left") {
      errObj = {
        result: parseResult(validationResult),
      };
    }
    return errObj;
  }
}

const NameType = t.type({
  first_name: t.string,
  middle_name: t.union([t.string, t.null]),
  last_name: t.string,
});

const DecedentType = t.type({
  external_id: t.string,
  domain: t.string,
  relative_path: t.string,
  name: t.union([NameType, t.null]),
  display_name: t.union([t.string, t.null]),
  date_of_birth: t.union([DateFromISOString, t.null]),
  birth_year: t.union([t.string, t.null]),
  date_of_death: t.union([DateFromISOString, t.null]),
  death_year: t.union([t.string, t.null]),
  obit_text: t.string,
});

export interface Decedent extends t.TypeOf<typeof DecedentType> {}

export class Decedent {
  public static validate(body: Decedent) {
    let errObj = {};
    const validationResult = t
      .exact(DecedentType)
      .decode(JSON.parse(JSON.stringify(body)));
    if (validationResult._tag === "Left") {
      errObj = {
        result: parseResult(validationResult),
      };
    }
    return errObj;
  }
}

const ServiceType = t.type({
  title: t.string,
  start_date: t.union([DateFromISOString, t.null]),
  end_date: t.union([DateFromISOString, t.null]),
  description: t.union([t.string, t.null]),
});

export interface Service extends t.TypeOf<typeof ServiceType> {}

export class Service {
  public static validate(body: Service) {
    let errObj = {};
    const validationResult = t
      .exact(ServiceType)
      .decode(JSON.parse(JSON.stringify(body)));
    if (validationResult._tag === "Left") {
      errObj = {
        result: parseResult(validationResult),
      };
    }
    return errObj;
  }
}

const ImageTypeType = t.union([
  t.literal("main-image"),
  t.literal("gallery-photo"),
  t.literal("image"),
]);

const ImageType = t.type({
  type: ImageTypeType,
  label: t.union([t.string, t.null]),
  url: t.string,
});

export interface Image extends t.TypeOf<typeof ImageType> {}

export class Image {
  public static validate(body: Image) {
    let errObj = {};
    const validationResult = t
      .exact(ImageType)
      .decode(JSON.parse(JSON.stringify(body)));
    if (validationResult._tag === "Left") {
      errObj = {
        result: parseResult(validationResult),
      };
    }
    return errObj;
  }
}

const LinkType = t.type({
  title: t.string,
  label: t.union([t.string, t.null]),
  url: t.string,
});

export interface Link extends t.TypeOf<typeof LinkType> {}

export class Link {
  public static validate(body: Link) {
    let errObj = {};
    const validationResult = t
      .exact(LinkType)
      .decode(JSON.parse(JSON.stringify(body)));
    if (validationResult._tag === "Left") {
      errObj = {
        result: parseResult(validationResult),
      };
    }
    return errObj;
  }
}

const MemoryMediaTypeType = t.union([
  t.literal("tribute-photo"),
  t.literal("store"),
  t.literal("candle"),
  t.literal("other-media"),
]);

const MemoryMediaType = t.type({
  type: MemoryMediaTypeType,
  label: t.union([t.string, t.null]),
  url: t.string,
});

export interface MemoryMedia extends t.TypeOf<typeof MemoryMediaType> {}

export class MemoryMedia {
  public static validate(body: MemoryMedia) {
    let errObj = {};
    const validationResult = t
      .exact(MemoryMediaType)
      .decode(JSON.parse(JSON.stringify(body)));
    if (validationResult._tag === "Left") {
      errObj = {
        result: parseResult(validationResult),
      };
    }
    return errObj;
  }
}

const MemoryReplyType = t.type({
  author: t.union([t.string, t.null]),
  date: t.union([DateFromISOString, t.null]),
  message: t.union([t.string, t.null]),
});

export interface MemoryReply extends t.TypeOf<typeof MemoryReplyType> {}

export class MemoryReply {
  public static validate(body: MemoryReply) {
    let errObj = {};
    const validationResult = t
      .exact(MemoryReplyType)
      .decode(JSON.parse(JSON.stringify(body)));
    if (validationResult._tag === "Left") {
      errObj = {
        result: parseResult(validationResult),
      };
    }
    return errObj;
  }
}

const MemoryTypeType = t.union([
  t.literal("store"),
  t.literal("media"),
  t.literal("text"),
  t.literal("candle"),
]);

const MemoryType = t.type({
  type: MemoryTypeType,
  author: t.union([t.string, t.null]),
  date: t.union([DateFromISOString, t.null]),
  message: t.string,
  email: t.union([t.string, t.null]),
  relationship: t.union([t.string, t.null]),
  media: t.array(MemoryMediaType),
  // replies: t.array(MemoryReplyType),
});

export interface Memory extends t.TypeOf<typeof MemoryType> {}

export class Memory {
  public static validate(body: Memory) {
    let errObj = {};
    const validationResult = t
      .exact(MemoryType)
      .decode(JSON.parse(JSON.stringify(body)));
    if (validationResult._tag === "Left") {
      errObj = {
        result: parseResult(validationResult),
      };
    }
    return errObj;
  }
}

const GatherCaseType = t.type({
  location: FuneralHomeType,
  decedent: DecedentType,
  services: t.array(ServiceType),
  images: t.array(ImageType),
  links: t.array(LinkType),
  memories: t.array(MemoryType),
});

export interface GatherCase extends t.TypeOf<typeof GatherCaseType> {}

export class GatherCase {
  public static validate(body: GatherCase) {
    let errObj = {};
    const validationResult = t
      .exact(GatherCaseType)
      .decode(JSON.parse(JSON.stringify(body)));
    if (validationResult._tag === "Left") {
      errObj = {
        result: parseResult(validationResult),
      };
    }
    return errObj;
  }
}

const parseResult = (validationResult: t.Validation<any>) => {
  let parsedResults = [];
  const validationArray = PathReporter.report(validationResult);
  for (let i = 0; i < validationArray.length; i++) {
    parsedResults.push(validationArray[i].split("/")[1]);
  }
  return parsedResults;
};

// Example usage
// const memory: Memory = {
// type: 'store',
// author: "John Doe",
// date: new Date(),
// message: "John was a great friend",
// email: "abc@xyz.com",
// relationship: null,
// media: [{ title: 'photo', label: null, url: 'https://google.com' }],
// };

// Memory.validate(memory); // will throw an error if it doesn't validate
