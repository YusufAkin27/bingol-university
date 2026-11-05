package edu.bingol.backend.forum.comment;

import org.springframework.data.jpa.repository.JpaRepository;

/** Yalnizca ekleme/kimlikle yukleme; tum sorgular ForumCommentStore'dadir (parametreli, sinirli). */
public interface ForumCommentRepository extends JpaRepository<ForumComment, Long> {
}
