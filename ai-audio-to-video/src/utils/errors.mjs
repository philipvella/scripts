export class ConfigError extends Error {
  constructor(message) {
    super(message);
    this.name = "ConfigError";
  }
}

export class InputError extends Error {
  constructor(message) {
    super(message);
    this.name = "InputError";
  }
}

export class ApiError extends Error {
  constructor(message) {
    super(message);
    this.name = "ApiError";
  }
}

export class RenderError extends Error {
  constructor(message) {
    super(message);
    this.name = "RenderError";
  }
}

