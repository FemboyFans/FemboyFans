SELECT id,
       antecedent_name,
       consequent_name,
       creator_id,
       forum_topic_id,
       status,
       created_at,
       updated_at,
       approver_id,
       forum_post_id,
       descendant_names,
       reason
FROM public.tag_implications ORDER BY id
