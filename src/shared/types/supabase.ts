export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      access_audit_log: {
        Row: {
          admin_id: string
          created_at: string
          id: string
          org_id: string
          reason: string
          target_user_id: string
        }
        Insert: {
          admin_id: string
          created_at?: string
          id?: string
          org_id: string
          reason: string
          target_user_id: string
        }
        Update: {
          admin_id?: string
          created_at?: string
          id?: string
          org_id?: string
          reason?: string
          target_user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "access_audit_log_admin_id_fkey"
            columns: ["admin_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "access_audit_log_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "access_audit_log_target_user_id_fkey"
            columns: ["target_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      action_log: {
        Row: {
          action_key: string
          contact_id: string | null
          context: string | null
          created_at: string
          energy: number
          id: string
          label: string
          location_id: string | null
          meta: Json | null
          org_id: string
          skill: string | null
          skill2: string | null
          user_id: string
          xp: number
        }
        Insert: {
          action_key: string
          contact_id?: string | null
          context?: string | null
          created_at?: string
          energy?: number
          id?: string
          label: string
          location_id?: string | null
          meta?: Json | null
          org_id: string
          skill?: string | null
          skill2?: string | null
          user_id: string
          xp: number
        }
        Update: {
          action_key?: string
          contact_id?: string | null
          context?: string | null
          created_at?: string
          energy?: number
          id?: string
          label?: string
          location_id?: string | null
          meta?: Json | null
          org_id?: string
          skill?: string | null
          skill2?: string | null
          user_id?: string
          xp?: number
        }
        Relationships: [
          {
            foreignKeyName: "action_log_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "action_log_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "action_log_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "action_log_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      contact_activities: {
        Row: {
          action_log_id: string | null
          betreff: string | null
          contact_id: string
          created_at: string
          id: string
          inhalt: string | null
          occurred_at: string
          org_id: string
          outcome: string | null
          type: string
          user_id: string
        }
        Insert: {
          action_log_id?: string | null
          betreff?: string | null
          contact_id: string
          created_at?: string
          id?: string
          inhalt?: string | null
          occurred_at?: string
          org_id: string
          outcome?: string | null
          type: string
          user_id: string
        }
        Update: {
          action_log_id?: string | null
          betreff?: string | null
          contact_id?: string
          created_at?: string
          id?: string
          inhalt?: string | null
          occurred_at?: string
          org_id?: string
          outcome?: string | null
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_activities_action_log_id_fkey"
            columns: ["action_log_id"]
            isOneToOne: false
            referencedRelation: "action_log"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_activities_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_activities_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_activities_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      contact_auto_delete_log: {
        Row: {
          deleted_count: number
          id: number
          org_id: string
          run_at: string
        }
        Insert: {
          deleted_count: number
          id?: never
          org_id: string
          run_at?: string
        }
        Update: {
          deleted_count?: number
          id?: never
          org_id?: string
          run_at?: string
        }
        Relationships: []
      }
      contact_deletion_requests: {
        Row: {
          contact_id: string | null
          contact_name_snapshot: string
          created_at: string
          id: string
          org_id: string
          requested_by: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
        }
        Insert: {
          contact_id?: string | null
          contact_name_snapshot: string
          created_at?: string
          id?: string
          org_id: string
          requested_by: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
        }
        Update: {
          contact_id?: string | null
          contact_name_snapshot?: string
          created_at?: string
          id?: string
          org_id?: string
          requested_by?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_deletion_requests_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_deletion_requests_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_deletion_requests_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_deletion_requests_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      contact_file_deletion_queue: {
        Row: {
          created_at: string
          id: number
          org_id: string
          storage_path: string
        }
        Insert: {
          created_at?: string
          id?: never
          org_id: string
          storage_path: string
        }
        Update: {
          created_at?: string
          id?: never
          org_id?: string
          storage_path?: string
        }
        Relationships: []
      }
      contact_files: {
        Row: {
          contact_id: string
          created_at: string
          filename: string
          id: string
          mime_type: string
          org_id: string
          size_bytes: number
          storage_path: string
          uploaded_by: string
        }
        Insert: {
          contact_id: string
          created_at?: string
          filename: string
          id?: string
          mime_type: string
          org_id: string
          size_bytes: number
          storage_path: string
          uploaded_by: string
        }
        Update: {
          contact_id?: string
          created_at?: string
          filename?: string
          id?: string
          mime_type?: string
          org_id?: string
          size_bytes?: number
          storage_path?: string
          uploaded_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_files_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_files_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_files_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      contacts: {
        Row: {
          bedarf_ist: string | null
          bedarf_wunsch: string | null
          consent_obtained: boolean
          created_at: string
          email: string | null
          geburtsdatum: string | null
          guild_id: string | null
          id: string
          kanban_stage: string | null
          location_id: string | null
          nachname: string
          naechster_kontakt: string | null
          name: string | null
          notes: string | null
          org_id: string
          owner_id: string | null
          role: string | null
          status: string
          telefon: string | null
          updated_at: string
          vorname: string
          wohnort_ort: string | null
          wohnort_strasse: string | null
        }
        Insert: {
          bedarf_ist?: string | null
          bedarf_wunsch?: string | null
          consent_obtained?: boolean
          created_at?: string
          email?: string | null
          geburtsdatum?: string | null
          guild_id?: string | null
          id?: string
          kanban_stage?: string | null
          location_id?: string | null
          nachname?: string
          naechster_kontakt?: string | null
          name?: string | null
          notes?: string | null
          org_id: string
          owner_id?: string | null
          role?: string | null
          status?: string
          telefon?: string | null
          updated_at?: string
          vorname?: string
          wohnort_ort?: string | null
          wohnort_strasse?: string | null
        }
        Update: {
          bedarf_ist?: string | null
          bedarf_wunsch?: string | null
          consent_obtained?: boolean
          created_at?: string
          email?: string | null
          geburtsdatum?: string | null
          guild_id?: string | null
          id?: string
          kanban_stage?: string | null
          location_id?: string | null
          nachname?: string
          naechster_kontakt?: string | null
          name?: string | null
          notes?: string | null
          org_id?: string
          owner_id?: string | null
          role?: string | null
          status?: string
          telefon?: string | null
          updated_at?: string
          vorname?: string
          wohnort_ort?: string | null
          wohnort_strasse?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "contacts_guild_id_fkey"
            columns: ["guild_id"]
            isOneToOne: false
            referencedRelation: "guilds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contacts_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contacts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contacts_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      error_log: {
        Row: {
          context: string
          created_at: string
          id: string
          message: string
          org_id: string
          user_id: string | null
        }
        Insert: {
          context: string
          created_at?: string
          id?: string
          message: string
          org_id: string
          user_id?: string | null
        }
        Update: {
          context?: string
          created_at?: string
          id?: string
          message?: string
          org_id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "error_log_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "error_log_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      friends: {
        Row: {
          created_at: string
          friend_id: string
          owner_id: string
          status: string
        }
        Insert: {
          created_at?: string
          friend_id: string
          owner_id: string
          status?: string
        }
        Update: {
          created_at?: string
          friend_id?: string
          owner_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "friends_friend_id_fkey"
            columns: ["friend_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friends_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      guild_invitations: {
        Row: {
          created_at: string
          guild_id: string
          id: string
          invited_by: string
          invited_user_id: string
          org_id: string
          responded_at: string | null
          status: string
        }
        Insert: {
          created_at?: string
          guild_id: string
          id?: string
          invited_by: string
          invited_user_id: string
          org_id: string
          responded_at?: string | null
          status?: string
        }
        Update: {
          created_at?: string
          guild_id?: string
          id?: string
          invited_by?: string
          invited_user_id?: string
          org_id?: string
          responded_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "guild_invitations_guild_id_fkey"
            columns: ["guild_id"]
            isOneToOne: false
            referencedRelation: "guilds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guild_invitations_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guild_invitations_invited_user_id_fkey"
            columns: ["invited_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guild_invitations_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      guild_members: {
        Row: {
          contacts_access: string
          dungeons_access: string
          guild_id: string
          joined_at: string
          member_id: string
          org_id: string
          team_rights: boolean
        }
        Insert: {
          contacts_access?: string
          dungeons_access?: string
          guild_id: string
          joined_at?: string
          member_id: string
          org_id: string
          team_rights?: boolean
        }
        Update: {
          contacts_access?: string
          dungeons_access?: string
          guild_id?: string
          joined_at?: string
          member_id?: string
          org_id?: string
          team_rights?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "guild_members_guild_id_fkey"
            columns: ["guild_id"]
            isOneToOne: false
            referencedRelation: "guilds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guild_members_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guild_members_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      guild_quest_log: {
        Row: {
          achieved_at: string
          guild_id: string
          id: string
          org_id: string
          period_key: string
          quest_id: string
          stage_id: string
        }
        Insert: {
          achieved_at?: string
          guild_id: string
          id?: string
          org_id: string
          period_key: string
          quest_id: string
          stage_id: string
        }
        Update: {
          achieved_at?: string
          guild_id?: string
          id?: string
          org_id?: string
          period_key?: string
          quest_id?: string
          stage_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "guild_quest_log_guild_id_fkey"
            columns: ["guild_id"]
            isOneToOne: false
            referencedRelation: "guilds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guild_quest_log_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      guilds: {
        Row: {
          created_at: string
          founder_id: string | null
          id: string
          name: string
          org_id: string
        }
        Insert: {
          created_at?: string
          founder_id?: string | null
          id?: string
          name: string
          org_id: string
        }
        Update: {
          created_at?: string
          founder_id?: string | null
          id?: string
          name?: string
          org_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "guilds_founder_id_fkey"
            columns: ["founder_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guilds_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      journal_entries: {
        Row: {
          entry_date: string
          org_id: string
          q1: string | null
          q2: string | null
          q3: string | null
          q4: string | null
          q5: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          entry_date: string
          org_id: string
          q1?: string | null
          q2?: string | null
          q3?: string | null
          q4?: string | null
          q5?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          entry_date?: string
          org_id?: string
          q1?: string | null
          q2?: string | null
          q3?: string | null
          q4?: string | null
          q5?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "journal_entries_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "journal_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      journal_entry_mentions: {
        Row: {
          contact_id: string
          created_at: string
          entry_date: string
          id: string
          org_id: string
          user_id: string
        }
        Insert: {
          contact_id: string
          created_at?: string
          entry_date: string
          id?: string
          org_id: string
          user_id: string
        }
        Update: {
          contact_id?: string
          created_at?: string
          entry_date?: string
          id?: string
          org_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "journal_entry_mentions_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "journal_entry_mentions_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "journal_entry_mentions_user_id_entry_date_fkey"
            columns: ["user_id", "entry_date"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["user_id", "entry_date"]
          },
          {
            foreignKeyName: "journal_entry_mentions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      journal_photos: {
        Row: {
          created_at: string
          entry_date: string
          id: string
          org_id: string
          storage_path: string
          transform_status: string
          transformed_path: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          entry_date: string
          id?: string
          org_id: string
          storage_path: string
          transform_status?: string
          transformed_path?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          entry_date?: string
          id?: string
          org_id?: string
          storage_path?: string
          transform_status?: string
          transformed_path?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "journal_photos_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "journal_photos_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      locations: {
        Row: {
          address: string | null
          created_at: string
          created_by: string | null
          guild_id: string | null
          id: string
          lat: number
          lng: number
          name: string
          org_id: string
          owner_id: string | null
          plz: string | null
          stadt: string | null
          strasse: string | null
          type: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          created_at?: string
          created_by?: string | null
          guild_id?: string | null
          id?: string
          lat: number
          lng: number
          name: string
          org_id: string
          owner_id?: string | null
          plz?: string | null
          stadt?: string | null
          strasse?: string | null
          type: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          created_at?: string
          created_by?: string | null
          guild_id?: string | null
          id?: string
          lat?: number
          lng?: number
          name?: string
          org_id?: string
          owner_id?: string | null
          plz?: string | null
          stadt?: string | null
          strasse?: string | null
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "locations_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "locations_guild_id_fkey"
            columns: ["guild_id"]
            isOneToOne: false
            referencedRelation: "guilds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "locations_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "locations_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      org_pool_invitations: {
        Row: {
          created_at: string
          id: string
          invited_by: string
          invited_user_id: string
          org_id: string
          responded_at: string | null
          status: string
        }
        Insert: {
          created_at?: string
          id?: string
          invited_by: string
          invited_user_id: string
          org_id: string
          responded_at?: string | null
          status?: string
        }
        Update: {
          created_at?: string
          id?: string
          invited_by?: string
          invited_user_id?: string
          org_id?: string
          responded_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "org_pool_invitations_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "org_pool_invitations_invited_user_id_fkey"
            columns: ["invited_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "org_pool_invitations_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          dissolved_at: string | null
          id: string
          name: string
          timezone: string
        }
        Insert: {
          created_at?: string
          dissolved_at?: string | null
          id?: string
          name: string
          timezone?: string
        }
        Update: {
          created_at?: string
          dissolved_at?: string | null
          id?: string
          name?: string
          timezone?: string
        }
        Relationships: []
      }
      platform_admin_actions: {
        Row: {
          action_type: string
          admin_id: string
          created_at: string
          id: string
          org_id: string
          reason: string | null
          target_user_id: string | null
        }
        Insert: {
          action_type: string
          admin_id: string
          created_at?: string
          id?: string
          org_id: string
          reason?: string | null
          target_user_id?: string | null
        }
        Update: {
          action_type?: string
          admin_id?: string
          created_at?: string
          id?: string
          org_id?: string
          reason?: string | null
          target_user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "platform_admin_actions_admin_id_fkey"
            columns: ["admin_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "platform_admin_actions_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "platform_admin_actions_target_user_id_fkey"
            columns: ["target_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      platform_admins: {
        Row: {
          added_at: string
          added_by: string | null
          user_id: string
        }
        Insert: {
          added_at?: string
          added_by?: string | null
          user_id: string
        }
        Update: {
          added_at?: string
          added_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "platform_admins_added_by_fkey"
            columns: ["added_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "platform_admins_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      pool_zuweisung_log: {
        Row: {
          assigned_at: string
          assigned_by: string
          entity_id: string
          entity_name_snapshot: string
          entity_type: string
          id: string
          new_guild_id: string | null
          new_owner_id: string | null
          org_id: string
        }
        Insert: {
          assigned_at?: string
          assigned_by: string
          entity_id: string
          entity_name_snapshot: string
          entity_type: string
          id?: string
          new_guild_id?: string | null
          new_owner_id?: string | null
          org_id: string
        }
        Update: {
          assigned_at?: string
          assigned_by?: string
          entity_id?: string
          entity_name_snapshot?: string
          entity_type?: string
          id?: string
          new_guild_id?: string | null
          new_owner_id?: string | null
          org_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "pool_zuweisung_log_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pool_zuweisung_log_new_guild_id_fkey"
            columns: ["new_guild_id"]
            isOneToOne: false
            referencedRelation: "guilds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pool_zuweisung_log_new_owner_id_fkey"
            columns: ["new_owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pool_zuweisung_log_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          active: boolean
          art: string | null
          bwp_faktor: number | null
          category: string
          created_at: string
          id: string
          key: string
          name: string
          org_id: string
          provision_faktor: number | null
          provision_mode: string
          recontact_amount: number | null
          recontact_unit: string | null
          subcategory: string | null
        }
        Insert: {
          active?: boolean
          art?: string | null
          bwp_faktor?: number | null
          category: string
          created_at?: string
          id?: string
          key: string
          name: string
          org_id: string
          provision_faktor?: number | null
          provision_mode?: string
          recontact_amount?: number | null
          recontact_unit?: string | null
          subcategory?: string | null
        }
        Update: {
          active?: boolean
          art?: string | null
          bwp_faktor?: number | null
          category?: string
          created_at?: string
          id?: string
          key?: string
          name?: string
          org_id?: string
          provision_faktor?: number | null
          provision_mode?: string
          recontact_amount?: number | null
          recontact_unit?: string | null
          subcategory?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "products_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          active_title: string | null
          arbeitszeiten: Json | null
          calendar_hide_weekends: boolean
          calendar_show_birthdays: boolean
          character_class: string
          chronik_show_xp: boolean
          company: string | null
          created_at: string
          display_name: string
          equipped_accessory: string | null
          equipped_armor: string | null
          equipped_weapon: string | null
          gender: string | null
          hair_style: string | null
          id: string
          kv_mb_satz: number | null
          last_seen_patch_number: number | null
          last_seen_pool_assignment: string | null
          last_seen_security_alert: string
          level: number
          lv_prozent_satz: number | null
          org_id: string | null
          planung_bwp: number | null
          planung_kv_mb: number | null
          planung_lv_bws: number | null
          pma_kv_satz: number | null
          pma_suh_satz: number | null
          real_name: string | null
          role: string
          skin_tone: string | null
          taetig_seit_jahr: number | null
          tasks_synced_date: string | null
          timezone: string | null
          total_xp: number
        }
        Insert: {
          active_title?: string | null
          arbeitszeiten?: Json | null
          calendar_hide_weekends?: boolean
          calendar_show_birthdays?: boolean
          character_class?: string
          chronik_show_xp?: boolean
          company?: string | null
          created_at?: string
          display_name?: string
          equipped_accessory?: string | null
          equipped_armor?: string | null
          equipped_weapon?: string | null
          gender?: string | null
          hair_style?: string | null
          id: string
          kv_mb_satz?: number | null
          last_seen_patch_number?: number | null
          last_seen_pool_assignment?: string | null
          last_seen_security_alert?: string
          level?: number
          lv_prozent_satz?: number | null
          org_id?: string | null
          planung_bwp?: number | null
          planung_kv_mb?: number | null
          planung_lv_bws?: number | null
          pma_kv_satz?: number | null
          pma_suh_satz?: number | null
          real_name?: string | null
          role?: string
          skin_tone?: string | null
          taetig_seit_jahr?: number | null
          tasks_synced_date?: string | null
          timezone?: string | null
          total_xp?: number
        }
        Update: {
          active_title?: string | null
          arbeitszeiten?: Json | null
          calendar_hide_weekends?: boolean
          calendar_show_birthdays?: boolean
          character_class?: string
          chronik_show_xp?: boolean
          company?: string | null
          created_at?: string
          display_name?: string
          equipped_accessory?: string | null
          equipped_armor?: string | null
          equipped_weapon?: string | null
          gender?: string | null
          hair_style?: string | null
          id?: string
          kv_mb_satz?: number | null
          last_seen_patch_number?: number | null
          last_seen_pool_assignment?: string | null
          last_seen_security_alert?: string
          level?: number
          lv_prozent_satz?: number | null
          org_id?: string | null
          planung_bwp?: number | null
          planung_kv_mb?: number | null
          planung_lv_bws?: number | null
          pma_kv_satz?: number | null
          pma_suh_satz?: number | null
          real_name?: string | null
          role?: string
          skin_tone?: string | null
          taetig_seit_jahr?: number | null
          tasks_synced_date?: string | null
          timezone?: string | null
          total_xp?: number
        }
        Relationships: [
          {
            foreignKeyName: "profiles_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      rule_configs: {
        Row: {
          config: Json
          org_id: string
          updated_at: string
        }
        Insert: {
          config: Json
          org_id: string
          updated_at?: string
        }
        Update: {
          config?: Json
          org_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "rule_configs_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      sales: {
        Row: {
          bewertungssumme: number | null
          contact_id: string
          created_at: string
          created_by: string | null
          datum: string
          id: string
          laufender_beitrag: number | null
          menge: number
          org_id: string
          product_id: string
          status: string
          updated_at: string
          vertragsbeginn: string | null
          vertragsende: string | null
          vertragsnummer: string | null
        }
        Insert: {
          bewertungssumme?: number | null
          contact_id: string
          created_at?: string
          created_by?: string | null
          datum?: string
          id?: string
          laufender_beitrag?: number | null
          menge?: number
          org_id: string
          product_id: string
          status?: string
          updated_at?: string
          vertragsbeginn?: string | null
          vertragsende?: string | null
          vertragsnummer?: string | null
        }
        Update: {
          bewertungssumme?: number | null
          contact_id?: string
          created_at?: string
          created_by?: string | null
          datum?: string
          id?: string
          laufender_beitrag?: number | null
          menge?: number
          org_id?: string
          product_id?: string
          status?: string
          updated_at?: string
          vertragsbeginn?: string | null
          vertragsende?: string | null
          vertragsnummer?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sales_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sales_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sales_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sales_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      schema_patches: {
        Row: {
          applied_at: string
          patch_number: number
          title: string
        }
        Insert: {
          applied_at?: string
          patch_number: number
          title: string
        }
        Update: {
          applied_at?: string
          patch_number?: number
          title?: string
        }
        Relationships: []
      }
      security_alerts: {
        Row: {
          created_at: string
          detail: string | null
          event_type: string
          id: string
          org_id: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          detail?: string | null
          event_type: string
          id?: string
          org_id: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          detail?: string | null
          event_type?: string
          id?: string
          org_id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "security_alerts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "security_alerts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      tasks: {
        Row: {
          contact_id: string | null
          created_at: string
          due_date: string | null
          id: string
          org_id: string
          owner_id: string
          source_type: string
          title: string
        }
        Insert: {
          contact_id?: string | null
          created_at?: string
          due_date?: string | null
          id?: string
          org_id: string
          owner_id: string
          source_type?: string
          title: string
        }
        Update: {
          contact_id?: string | null
          created_at?: string
          due_date?: string | null
          id?: string
          org_id?: string
          owner_id?: string
          source_type?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "tasks_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      termin_invitations: {
        Row: {
          contact_id: string | null
          created_at: string
          end_at: string | null
          id: string
          invited_user_id: string
          invitee_termin_id: string | null
          kanal: string | null
          org_id: string
          organizer_id: string | null
          responded_at: string | null
          start_at: string | null
          status: string
          termin_id: string | null
          title: string | null
        }
        Insert: {
          contact_id?: string | null
          created_at?: string
          end_at?: string | null
          id?: string
          invited_user_id: string
          invitee_termin_id?: string | null
          kanal?: string | null
          org_id: string
          organizer_id?: string | null
          responded_at?: string | null
          start_at?: string | null
          status?: string
          termin_id?: string | null
          title?: string | null
        }
        Update: {
          contact_id?: string | null
          created_at?: string
          end_at?: string | null
          id?: string
          invited_user_id?: string
          invitee_termin_id?: string | null
          kanal?: string | null
          org_id?: string
          organizer_id?: string | null
          responded_at?: string | null
          start_at?: string | null
          status?: string
          termin_id?: string | null
          title?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "termin_invitations_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termin_invitations_invited_user_id_fkey"
            columns: ["invited_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termin_invitations_invitee_termin_id_fkey"
            columns: ["invitee_termin_id"]
            isOneToOne: false
            referencedRelation: "termine"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termin_invitations_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termin_invitations_organizer_id_fkey"
            columns: ["organizer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termin_invitations_termin_id_fkey"
            columns: ["termin_id"]
            isOneToOne: false
            referencedRelation: "termine"
            referencedColumns: ["id"]
          },
        ]
      }
      termin_series: {
        Row: {
          contact_id: string | null
          created_at: string
          end_time: string
          freq: string
          generated_until: string
          id: string
          interval_n: number
          kanal: string | null
          location_id: string | null
          org_id: string
          owner_id: string
          start_date: string
          start_time: string
          title: string
          until_date: string | null
          updated_at: string
          weekdays: number[] | null
        }
        Insert: {
          contact_id?: string | null
          created_at?: string
          end_time: string
          freq: string
          generated_until: string
          id?: string
          interval_n?: number
          kanal?: string | null
          location_id?: string | null
          org_id: string
          owner_id: string
          start_date: string
          start_time: string
          title: string
          until_date?: string | null
          updated_at?: string
          weekdays?: number[] | null
        }
        Update: {
          contact_id?: string | null
          created_at?: string
          end_time?: string
          freq?: string
          generated_until?: string
          id?: string
          interval_n?: number
          kanal?: string | null
          location_id?: string | null
          org_id?: string
          owner_id?: string
          start_date?: string
          start_time?: string
          title?: string
          until_date?: string | null
          updated_at?: string
          weekdays?: number[] | null
        }
        Relationships: [
          {
            foreignKeyName: "termin_series_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termin_series_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termin_series_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termin_series_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      termine: {
        Row: {
          contact_id: string | null
          created_at: string
          end_at: string
          id: string
          kanal: string | null
          location_id: string | null
          org_id: string
          organizer_id: string | null
          owner_id: string
          series_id: string | null
          start_at: string
          title: string
          updated_at: string
        }
        Insert: {
          contact_id?: string | null
          created_at?: string
          end_at: string
          id?: string
          kanal?: string | null
          location_id?: string | null
          org_id: string
          organizer_id?: string | null
          owner_id: string
          series_id?: string | null
          start_at: string
          title: string
          updated_at?: string
        }
        Update: {
          contact_id?: string | null
          created_at?: string
          end_at?: string
          id?: string
          kanal?: string | null
          location_id?: string | null
          org_id?: string
          organizer_id?: string | null
          owner_id?: string
          series_id?: string | null
          start_at?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "termine_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termine_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termine_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termine_organizer_id_fkey"
            columns: ["organizer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termine_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "termine_series_id_fkey"
            columns: ["series_id"]
            isOneToOne: false
            referencedRelation: "termin_series"
            referencedColumns: ["id"]
          },
        ]
      }
      user_inventory: {
        Row: {
          item_key: string
          org_id: string
          quantity: number
          updated_at: string
          user_id: string
        }
        Insert: {
          item_key: string
          org_id: string
          quantity?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          item_key?: string
          org_id?: string
          quantity?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_inventory_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_inventory_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_create_guild: {
        Args: { p_founder_user_id: string; p_name: string }
        Returns: string
      }
      admin_emergency_access: {
        Args: { p_reason: string; p_target_user: string }
        Returns: Json
      }
      admin_reassign_contact: {
        Args: {
          p_contact_id: string
          p_expected_updated_at: string
          p_new_guild_id: string
          p_new_owner_id: string
        }
        Returns: {
          bedarf_ist: string | null
          bedarf_wunsch: string | null
          consent_obtained: boolean
          created_at: string
          email: string | null
          geburtsdatum: string | null
          guild_id: string | null
          id: string
          kanban_stage: string | null
          location_id: string | null
          nachname: string
          naechster_kontakt: string | null
          name: string | null
          notes: string | null
          org_id: string
          owner_id: string | null
          role: string | null
          status: string
          telefon: string | null
          updated_at: string
          vorname: string
          wohnort_ort: string | null
          wohnort_strasse: string | null
        }
        SetofOptions: {
          from: "*"
          to: "contacts"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admit_location_to_guild_pool_locked: {
        Args: {
          p_expected_updated_at: string
          p_guild_id: string
          p_id: string
        }
        Returns: {
          address: string | null
          created_at: string
          created_by: string | null
          guild_id: string | null
          id: string
          lat: number
          lng: number
          name: string
          org_id: string
          owner_id: string | null
          plz: string | null
          stadt: string | null
          strasse: string | null
          type: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "locations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      approve_contact_deletion_request: {
        Args: { p_request_id: string }
        Returns: undefined
      }
      assign_location_owner_locked: {
        Args: {
          p_expected_updated_at: string
          p_id: string
          p_owner_id: string
        }
        Returns: {
          address: string | null
          created_at: string
          created_by: string | null
          guild_id: string | null
          id: string
          lat: number
          lng: number
          name: string
          org_id: string
          owner_id: string | null
          plz: string | null
          stadt: string | null
          strasse: string | null
          type: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "locations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      attach_kanal_to_own_action: {
        Args: { p_kanal: string; p_log_id: string }
        Returns: {
          action_key: string
          contact_id: string | null
          context: string | null
          created_at: string
          energy: number
          id: string
          label: string
          location_id: string | null
          meta: Json | null
          org_id: string
          skill: string | null
          skill2: string | null
          user_id: string
          xp: number
        }
        SetofOptions: {
          from: "*"
          to: "action_log"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      auto_delete_inactive_contacts: { Args: never; Returns: undefined }
      cancel_guild_invitation: {
        Args: { p_invitation_id: string }
        Returns: undefined
      }
      cancel_org_pool_invitation: {
        Args: { p_invitation_id: string }
        Returns: undefined
      }
      cancel_sale_locked: {
        Args: {
          p_expected_updated_at: string
          p_id: string
          p_vertragsende: string
        }
        Returns: {
          bewertungssumme: number | null
          contact_id: string
          created_at: string
          created_by: string | null
          datum: string
          id: string
          laufender_beitrag: number | null
          menge: number
          org_id: string
          product_id: string
          status: string
          updated_at: string
          vertragsbeginn: string | null
          vertragsende: string | null
          vertragsnummer: string | null
        }
        SetofOptions: {
          from: "*"
          to: "sales"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      clear_contact_file_cleanup_queue: {
        Args: { p_ids: number[] }
        Returns: undefined
      }
      consume_item_from_self: {
        Args: { p_item_key: string }
        Returns: undefined
      }
      contacts_pending_deletion_for_self: {
        Args: never
        Returns: {
          contact_id: string
          deletion_date: string
          nachname: string
          vorname: string
        }[]
      }
      contacts_shared_for_org: { Args: never; Returns: boolean }
      contacts_writable: {
        Args: { target: Database["public"]["Tables"]["contacts"]["Row"] }
        Returns: boolean
      }
      current_org_id: { Args: never; Returns: string }
      found_own_org: {
        Args: { p_guild_name: string; p_org_name: string }
        Returns: string
      }
      friend_link_profiles: {
        Args: never
        Returns: {
          active_title: string
          character_class: string
          display_name: string
          equipped_accessory: string
          equipped_armor: string
          equipped_weapon: string
          gender: string
          hair_style: string
          id: string
          level: number
          skin_tone: string
        }[]
      }
      friend_skill_totals: {
        Args: { target_user: string }
        Returns: {
          skill_key: string
          xp_sum: number
        }[]
      }
      grant_guild_quest_completion: {
        Args: {
          p_guild_id: string
          p_period_key: string
          p_quest_id: string
          p_stage_id: string
        }
        Returns: boolean
      }
      grant_item_to_self: { Args: { p_item_key: string }; Returns: undefined }
      grant_quest_bonus_to_self: {
        Args: {
          p_kind: string
          p_period_key?: string
          p_quest_id: string
          p_stage_id?: string
        }
        Returns: {
          action_key: string
          contact_id: string | null
          context: string | null
          created_at: string
          energy: number
          id: string
          label: string
          location_id: string | null
          meta: Json | null
          org_id: string
          skill: string | null
          skill2: string | null
          user_id: string
          xp: number
        }
        SetofOptions: {
          from: "*"
          to: "action_log"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      guild_contact_permission: {
        Args: { need_write: boolean; target_owner: string }
        Returns: boolean
      }
      guild_dungeon_permission: {
        Args: { loc_guild_id: string; need_write: boolean }
        Returns: boolean
      }
      guild_founder_of_member: {
        Args: { target_owner: string }
        Returns: boolean
      }
      guild_leadership_permission: {
        Args: { target_guild: string }
        Returns: boolean
      }
      guild_pool_read_permission: {
        Args: { target_guild: string }
        Returns: boolean
      }
      guild_sales_metric_total: {
        Args: {
          p_category: string
          p_field: string
          p_guild_id: string
          p_year: number
        }
        Returns: number
      }
      invite_to_guild: {
        Args: { p_guild_id: string; p_invited_user_id: string }
        Returns: string
      }
      invite_to_org_pool: {
        Args: { p_invited_user_id: string }
        Returns: string
      }
      invite_to_termin: {
        Args: { p_invited_user_id: string; p_termin_id: string }
        Returns: string
      }
      is_admin: { Args: never; Returns: boolean }
      is_admin_of: { Args: { p_org_id: string }; Returns: boolean }
      is_platform_admin: { Args: never; Returns: boolean }
      is_sole_guild_founder_of_org: {
        Args: { p_org_id: string }
        Returns: boolean
      }
      leave_own_org: { Args: never; Returns: undefined }
      locations_writable: {
        Args: { target: Database["public"]["Tables"]["locations"]["Row"] }
        Returns: boolean
      }
      log_action_for_self: {
        Args: {
          p_action_key: string
          p_contact_id?: string
          p_context?: string
          p_location_id?: string
          p_meta?: Json
          p_occurred_at?: string
        }
        Returns: {
          action_key: string
          contact_id: string | null
          context: string | null
          created_at: string
          energy: number
          id: string
          label: string
          location_id: string | null
          meta: Json | null
          org_id: string
          skill: string | null
          skill2: string | null
          user_id: string
          xp: number
        }
        SetofOptions: {
          from: "*"
          to: "action_log"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      log_item_energy_refill_for_self: {
        Args: { p_item_key: string }
        Returns: {
          action_key: string
          contact_id: string | null
          context: string | null
          created_at: string
          energy: number
          id: string
          label: string
          location_id: string | null
          meta: Json | null
          org_id: string
          skill: string | null
          skill2: string | null
          user_id: string
          xp: number
        }
        SetofOptions: {
          from: "*"
          to: "action_log"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      log_security_alert: {
        Args: { p_detail?: string; p_event_type: string; p_user_id: string }
        Returns: undefined
      }
      notify_termin_update: { Args: { p_termin_id: string }; Returns: number }
      platform_admin_emergency_access: {
        Args: { p_reason: string; p_target_user: string }
        Returns: Json
      }
      platform_admin_list_orgs: {
        Args: never
        Returns: {
          id: string
          name: string
        }[]
      }
      platform_admin_update_rule_config: {
        Args: { p_config: Json; p_org_id: string }
        Returns: undefined
      }
      reassign_guild_founder_on_departure: {
        Args: { p_leaving_id: string }
        Returns: undefined
      }
      reject_contact_deletion_request: {
        Args: { p_request_id: string }
        Returns: undefined
      }
      request_contact_deletion: {
        Args: { p_contact_id: string }
        Returns: string
      }
      respond_to_guild_invitation: {
        Args: { p_accept: boolean; p_invitation_id: string }
        Returns: undefined
      }
      respond_to_org_pool_invitation: {
        Args: { p_accept: boolean; p_invitation_id: string }
        Returns: undefined
      }
      respond_to_termin_invitation: {
        Args: { p_accept: boolean; p_invitation_id: string }
        Returns: undefined
      }
      sales_writable: {
        Args: { target: Database["public"]["Tables"]["sales"]["Row"] }
        Returns: boolean
      }
      search_org_pool_candidates: {
        Args: { p_name: string }
        Returns: {
          character_class: string
          display_name: string
          id: string
          real_name: string
        }[]
      }
      search_profile_for_friend: {
        Args: { p_name: string }
        Returns: {
          character_class: string
          display_name: string
          id: string
        }[]
      }
      socially_visible: { Args: { target_user: string }; Returns: boolean }
      sync_own_level_cache: {
        Args: never
        Returns: {
          level: number
          total_xp: number
        }[]
      }
      termin_series_writable: {
        Args: { target: Database["public"]["Tables"]["termin_series"]["Row"] }
        Returns: boolean
      }
      termine_writable: {
        Args: { target: Database["public"]["Tables"]["termine"]["Row"] }
        Returns: boolean
      }
      update_contact_locked: {
        Args: { p_expected_updated_at: string; p_id: string; p_patch: Json }
        Returns: {
          bedarf_ist: string | null
          bedarf_wunsch: string | null
          consent_obtained: boolean
          created_at: string
          email: string | null
          geburtsdatum: string | null
          guild_id: string | null
          id: string
          kanban_stage: string | null
          location_id: string | null
          nachname: string
          naechster_kontakt: string | null
          name: string | null
          notes: string | null
          org_id: string
          owner_id: string | null
          role: string | null
          status: string
          telefon: string | null
          updated_at: string
          vorname: string
          wohnort_ort: string | null
          wohnort_strasse: string | null
        }
        SetofOptions: {
          from: "*"
          to: "contacts"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_termin_locked: {
        Args: { p_expected_updated_at: string; p_id: string; p_patch: Json }
        Returns: {
          contact_id: string | null
          created_at: string
          end_at: string
          id: string
          kanal: string | null
          location_id: string | null
          org_id: string
          organizer_id: string | null
          owner_id: string
          series_id: string | null
          start_at: string
          title: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "termine"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_termin_series_locked: {
        Args: { p_expected_updated_at: string; p_id: string; p_patch: Json }
        Returns: {
          contact_id: string | null
          created_at: string
          end_time: string
          freq: string
          generated_until: string
          id: string
          interval_n: number
          kanal: string | null
          location_id: string | null
          org_id: string
          owner_id: string
          start_date: string
          start_time: string
          title: string
          until_date: string | null
          updated_at: string
          weekdays: number[] | null
        }
        SetofOptions: {
          from: "*"
          to: "termin_series"
          isOneToOne: true
          isSetofReturn: false
        }
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
