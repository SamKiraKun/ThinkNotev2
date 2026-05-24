declare global {
  namespace Express {
    interface Request {
      request_id: string;
      user_id: string;
      auth_user: {
        id: string;
        email: string | null;
        name: string | null;
        avatarUrl: string | null;
      };
    }
  }
}

export {};
